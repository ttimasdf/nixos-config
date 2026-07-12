#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Symlink the locked root nixpkgs input source into source/.

By default this reads ./flake.lock, resolves .root, then resolves
nodes.<root>.inputs.nixpkgs (which may point at nixpkgs, nixpkgs_2, etc.),
then creates:

  source/nixpkgs-nixos-unstable-YYYYMMDD -> /nix/store/...
  source/nixpkgs-nixos-unstable-latest -> nixpkgs-nixos-unstable-YYYYMMDD

Options:
  --lock-file PATH   flake.lock path (default: repo root flake.lock)
  --source-dir PATH  output source directory (default: repo root source)
  --prefix NAME      symlink name prefix (default: nixpkgs-nixos-unstable)
  --dry-run          print what would be linked without changing files
  -h, --help         show this help message
EOF
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
lock_file="${FLAKE_LOCK:-${repo_root}/flake.lock}"
source_dir="${SOURCE_DIR:-${repo_root}/source}"
prefix="${NIXPKGS_SOURCE_PREFIX:-nixpkgs-nixos-unstable}"
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
        --prefix)
            prefix="$2"
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

# Resolve the actual nixpkgs node from nodes.<root>.inputs.nixpkgs. This can be
# named "nixpkgs", "nixpkgs_2", etc. depending on the lock graph.
nixpkgs_node="$(
    jq -r --arg root "$root_node" '
      .nodes[$root].inputs.nixpkgs
      | if type == "string" then .
        elif type == "array" then .[-1]
        else empty
        end
    ' "$lock_file"
)"

if [[ -z "$nixpkgs_node" || "$nixpkgs_node" == "null" ]]; then
    echo "Error: nodes.${root_node}.inputs.nixpkgs not found in $lock_file" >&2
    exit 1
fi

if ! jq -e --arg node "$nixpkgs_node" '.nodes[$node].locked' "$lock_file" >/dev/null; then
    echo "Error: nodes.${root_node}.inputs.nixpkgs points to missing locked node '${nixpkgs_node}'" >&2
    exit 1
fi

last_modified="$(jq -r --arg node "$nixpkgs_node" '.nodes[$node].locked.lastModified // empty' "$lock_file")"
if [[ ! "$last_modified" =~ ^[0-9]+$ ]]; then
    echo "Error: nodes.${nixpkgs_node}.locked.lastModified is missing or invalid" >&2
    exit 1
fi

if date -u -d "@0" +%Y%m%d >/dev/null 2>&1; then
    lock_date="$(date -u -d "@${last_modified}" +%Y%m%d)"
else
    lock_date="$(date -u -r "$last_modified" +%Y%m%d)"
fi

lock_type="$(jq -r --arg node "$nixpkgs_node" '.nodes[$node].locked.type // empty' "$lock_file")"

make_flake_ref() {
    jq -r --arg node "$nixpkgs_node" '
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
    local raw_path
    raw_path="$(jq -r --arg node "$nixpkgs_node" '.nodes[$node].locked.path // empty' "$lock_file")"
    if [[ -z "$raw_path" ]]; then
        echo "Error: path input '${nixpkgs_node}' has no locked.path" >&2
        exit 1
    fi

    if [[ "$raw_path" = /* ]]; then
        printf '%s\n' "$raw_path"
    else
        printf '%s\n' "${repo_root}/${raw_path}"
    fi
}

if [[ "$lock_type" == "path" ]]; then
    nixpkgs_source="$(resolve_path_input)"
else
    flake_ref="$(make_flake_ref)"
    if [[ -z "$flake_ref" ]]; then
        echo "Error: cannot construct flake ref for locked node '${nixpkgs_node}' of type '${lock_type}'" >&2
        exit 1
    fi

    nix_cmd=(nix --extra-experimental-features "nix-command flakes")
    prefetch_json="$("${nix_cmd[@]}" flake prefetch --json "$flake_ref")"
    nixpkgs_source="$(jq -r '.storePath // .path // empty' <<< "$prefetch_json")"

    if [[ -z "$nixpkgs_source" || "$nixpkgs_source" == "null" ]]; then
        echo "Error: nix flake prefetch did not return a store path for $flake_ref" >&2
        exit 1
    fi
fi

if [[ ! -e "$nixpkgs_source" ]]; then
    echo "Error: resolved source path does not exist: $nixpkgs_source" >&2
    exit 1
fi

dated_link="${source_dir}/${prefix}-${lock_date}"
latest_link="${source_dir}/${prefix}-latest"

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

if [[ "$dry_run" -eq 1 ]]; then
    cat <<EOF
root node:    .root -> ${root_node}
nixpkgs node: nodes.${root_node}.inputs.nixpkgs -> ${nixpkgs_node}
source:       ${nixpkgs_source}
dated link:  ${dated_link}
latest link: ${latest_link} -> $(basename "$dated_link")
EOF
    exit 0
fi

mkdir -p -- "$source_dir"
replace_symlink "$nixpkgs_source" "$dated_link"
replace_symlink "$(basename "$dated_link")" "$latest_link"

cat <<EOF
Linked locked nixpkgs source.
root node:    .root -> ${root_node}
nixpkgs node: nodes.${root_node}.inputs.nixpkgs -> ${nixpkgs_node}
source:       ${nixpkgs_source}
dated link:  ${dated_link}
latest link: ${latest_link} -> $(basename "$dated_link")
EOF
