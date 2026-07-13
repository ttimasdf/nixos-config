#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Symlink locked root input sources into source/.

This reads ./flake.lock, resolves .root, then resolves these root inputs:

  nodes.<root>.inputs.nixpkgs      -> source/nixpkgs-nixos-unstable-YYYYMMDD
  nodes.<root>.inputs.home-manager -> source/home-manager-YYYYMMDD

Each input's YYYYMMDD comes from that locked node's lastModified value. The
script also updates matching -latest symlinks:

  source/nixpkgs-nixos-unstable-latest -> nixpkgs-nixos-unstable-YYYYMMDD
  source/home-manager-latest           -> home-manager-YYYYMMDD

Options:
  --lock-file PATH        flake.lock path (default: repo root flake.lock)
  --source-dir PATH       output source directory (default: repo root source)
  --nixpkgs-prefix NAME   nixpkgs symlink prefix (default: nixpkgs-nixos-unstable)
  --dry-run               print what would be linked without changing files
  -h, --help              show this help message
EOF
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
lock_file="${FLAKE_LOCK:-${repo_root}/flake.lock}"
source_dir="${SOURCE_DIR:-${repo_root}/source}"
nixpkgs_prefix="${NIXPKGS_SOURCE_PREFIX:-nixpkgs-nixos-unstable}"
home_manager_prefix="home-manager"
dry_run=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lock-file)
            lock_file="$2"
            shift 2
            ;;
        --source-dir)
            source_dir="$2"
            shift 2
            ;;
        --nixpkgs-prefix|--prefix)
            nixpkgs_prefix="$2"
            shift 2
            ;;
        --dry-run)
            dry_run=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

for cmd in jq nix date; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: Required command not found: $cmd" >&2
        exit 1
    fi
done

if [[ ! -f "$lock_file" ]]; then
    echo "Error: flake.lock not found: $lock_file" >&2
    exit 1
fi

# Resolve the flake root node first. It is often named "root", but the
# authoritative key is the top-level .root value in flake.lock.
root_node="$(jq -r '.root // empty' "$lock_file")"

if [[ -z "$root_node" || "$root_node" == "null" ]]; then
    echo "Error: top-level .root not found in $lock_file" >&2
    exit 1
fi

if ! jq -e --arg root "$root_node" '.nodes[$root]' "$lock_file" >/dev/null; then
    echo "Error: .root points to missing node '${root_node}'" >&2
    exit 1
fi

if date -u -d "@0" +%Y%m%d >/dev/null 2>&1; then
    date_from_epoch() { date -u -d "@$1" +%Y%m%d; }
else
    date_from_epoch() { date -u -r "$1" +%Y%m%d; }
fi

resolve_root_input_node() {
    local input_name="$1"
    local node

    node="$(
        jq -r --arg root "$root_node" --arg input "$input_name" '
          .nodes[$root].inputs[$input]
          | if type == "string" then .
            elif type == "array" then .[-1]
            else empty
            end
        ' "$lock_file"
    )"

    if [[ -z "$node" || "$node" == "null" ]]; then
        echo "Error: nodes.${root_node}.inputs.${input_name} not found in $lock_file" >&2
        exit 1
    fi

    if ! jq -e --arg node "$node" '.nodes[$node].locked' "$lock_file" >/dev/null; then
        echo "Error: nodes.${root_node}.inputs.${input_name} points to missing locked node '${node}'" >&2
        exit 1
    fi

    printf '%s\n' "$node"
}

make_flake_ref() {
    local node="$1"

    jq -r --arg node "$node" '
      .nodes[$node].locked as $l |
      if $l.type == "github" then
        "github:\($l.owner)/\($l.repo)/\($l.rev // $l.ref)"
      elif $l.type == "gitlab" then
        "gitlab:\($l.owner)/\($l.repo)/\($l.rev // $l.ref)"
      elif $l.type == "git" then
        "git+\($l.url)?rev=\($l.rev)"
      elif ($l.url? // empty) != "" then
        $l.url
      else
        empty
      end
    ' "$lock_file"
}

resolve_path_input() {
    local node="$1"
    local raw_path

    raw_path="$(jq -r --arg node "$node" '.nodes[$node].locked.path // empty' "$lock_file")"
    if [[ -z "$raw_path" ]]; then
        echo "Error: path input '${node}' has no locked.path" >&2
        exit 1
    fi

    if [[ "$raw_path" = /* ]]; then
        printf '%s\n' "$raw_path"
    else
        printf '%s\n' "${repo_root}/${raw_path}"
    fi
}

resolve_source_path() {
    local node="$1"
    local lock_type flake_ref prefetch_json source_path

    lock_type="$(jq -r --arg node "$node" '.nodes[$node].locked.type // empty' "$lock_file")"

    if [[ "$lock_type" == "path" ]]; then
        resolve_path_input "$node"
        return
    fi

    flake_ref="$(make_flake_ref "$node")"
    if [[ -z "$flake_ref" ]]; then
        echo "Error: cannot construct flake ref for locked node '${node}' of type '${lock_type}'" >&2
        exit 1
    fi

    prefetch_json="$(nix --extra-experimental-features "nix-command flakes" flake prefetch --json "$flake_ref")"
    source_path="$(jq -r '.storePath // .path // empty' <<< "$prefetch_json")"

    if [[ -z "$source_path" || "$source_path" == "null" ]]; then
        echo "Error: nix flake prefetch did not return a store path for $flake_ref" >&2
        exit 1
    fi

    printf '%s\n' "$source_path"
}

replace_symlink() {
    local target="$1"
    local link="$2"

    if [[ -e "$link" && ! -L "$link" ]]; then
        echo "Error: Refusing to replace non-symlink path: $link" >&2
        exit 1
    fi

    rm -f -- "$link"
    ln -s -- "$target" "$link"
}

link_locked_input() {
    local input_name="$1"
    local link_prefix="$2"
    local node last_modified lock_date source_path dated_link latest_link

    node="$(resolve_root_input_node "$input_name")"

    last_modified="$(jq -r --arg node "$node" '.nodes[$node].locked.lastModified // empty' "$lock_file")"
    if [[ ! "$last_modified" =~ ^[0-9]+$ ]]; then
        echo "Error: nodes.${node}.locked.lastModified is missing or invalid" >&2
        exit 1
    fi

    lock_date="$(date_from_epoch "$last_modified")"
    source_path="$(resolve_source_path "$node")"

    if [[ ! -e "$source_path" ]]; then
        echo "Error: resolved source path does not exist: $source_path" >&2
        exit 1
    fi

    dated_link="${source_dir}/${link_prefix}-${lock_date}"
    latest_link="${source_dir}/${link_prefix}-latest"

    if [[ "$dry_run" -eq 1 ]]; then
        cat <<EOF
input:       nodes.${root_node}.inputs.${input_name} -> ${node}
source:      ${source_path}
dated link: ${dated_link}
latest link: ${latest_link} -> $(basename "$dated_link")
EOF
        return
    fi

    replace_symlink "$source_path" "$dated_link"
    replace_symlink "$(basename "$dated_link")" "$latest_link"

    cat <<EOF
Linked ${input_name} source.
input:       nodes.${root_node}.inputs.${input_name} -> ${node}
source:      ${source_path}
dated link: ${dated_link}
latest link: ${latest_link} -> $(basename "$dated_link")
EOF
}

if [[ "$dry_run" -eq 1 ]]; then
    echo "root node:   .root -> ${root_node}"
    echo
    link_locked_input "nixpkgs" "$nixpkgs_prefix"
    echo
    link_locked_input "home-manager" "$home_manager_prefix"
    exit 0
fi

mkdir -p -- "$source_dir"
echo "root node:   .root -> ${root_node}"
echo
link_locked_input "nixpkgs" "$nixpkgs_prefix"
echo
link_locked_input "home-manager" "$home_manager_prefix"
