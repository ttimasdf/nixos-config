#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 INPUT COMMIT

Update one root flake input in flake.lock to an exact commit without changing
flake.nix. The input's existing repository and source type are reused.

Arguments:
  INPUT       Root flake input name, for example known-rabbit-packages
  COMMIT      Exact commit to lock, preferably a full 40-character SHA

The source is prefetched first. Its NAR hash and metadata are then written to
flake.lock, while the input's original flake.nix reference is preserved.
EOF
}

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -ne 2 ]]; then
    echo "Error: expected INPUT and COMMIT" >&2
    usage >&2
    exit 1
fi

input_name="$1"
commit="$2"

if [[ ! "$commit" =~ ^[[:xdigit:]]{40}$ ]]; then
    echo "Error: COMMIT must be a full 40-character hexadecimal commit SHA" >&2
    exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
lock_file="${repo_root}/flake.lock"
flake_file="${repo_root}/flake.nix"

for command in jq nix sha256sum; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Error: required command not found: $command" >&2
        exit 1
    fi
done

if [[ ! -f "$lock_file" ]]; then
    echo "Error: flake.lock not found: $lock_file" >&2
    exit 1
fi

if [[ ! -f "$flake_file" ]]; then
    echo "Error: flake.nix not found: $flake_file" >&2
    exit 1
fi

flake_hash_before="$(sha256sum "$flake_file")"

root_node="$(jq -er '.root' "$lock_file")"
node="$(jq -er \
    --arg root "$root_node" \
    --arg input "$input_name" \
    '.nodes[$root].inputs[$input]
     | if type == "string" then .
       elif type == "array" then .[-1]
       else error("input must refer to a node")
       end' \
    "$lock_file")"

if ! jq -e --arg node "$node" '.nodes[$node].locked' "$lock_file" >/dev/null; then
    echo "Error: input '$input_name' points to missing or unlocked node '$node'" >&2
    exit 1
fi

locked_type="$(jq -er --arg node "$node" '.nodes[$node].locked.type' "$lock_file")"
owner="$(jq -er --arg node "$node" '.nodes[$node].locked.owner' "$lock_file" 2>/dev/null || true)"
repo="$(jq -er --arg node "$node" '.nodes[$node].locked.repo' "$lock_file" 2>/dev/null || true)"
url="$(jq -er --arg node "$node" '.nodes[$node].locked.url' "$lock_file" 2>/dev/null || true)"

case "$locked_type" in
    github)
        [[ -n "$owner" && -n "$repo" ]] || {
            echo "Error: GitHub input '$input_name' has no owner/repo metadata" >&2
            exit 1
        }
        flake_ref="github:${owner}/${repo}/${commit}"
        ;;
    gitlab)
        [[ -n "$owner" && -n "$repo" ]] || {
            echo "Error: GitLab input '$input_name' has no owner/repo metadata" >&2
            exit 1
        }
        flake_ref="gitlab:${owner}/${repo}/${commit}"
        ;;
    git)
        [[ -n "$url" ]] || {
            echo "Error: Git input '$input_name' has no URL metadata" >&2
            exit 1
        }
        flake_ref="git+${url}?rev=${commit}"
        ;;
    *)
        echo "Error: unsupported locked input type '$locked_type' for '$input_name'" >&2
        exit 1
        ;;
esac

echo "Prefetching ${flake_ref}..." >&2
prefetch_json="$(nix --extra-experimental-features "nix-command flakes" flake prefetch --json "$flake_ref")"

prefetched_rev="$(jq -er '.locked.rev' <<<"$prefetch_json")"
if [[ "${prefetched_rev,,}" != "${commit,,}" ]]; then
    echo "Error: prefetch resolved commit '$prefetched_rev', expected '$commit'" >&2
    exit 1
fi

nar_hash="$(jq -er '.hash // .narHash' <<<"$prefetch_json")"
prefetched_locked="$(jq -c --arg nar_hash "$nar_hash" '.locked + { narHash: $nar_hash }' <<<"$prefetch_json")"

lock_tmp="$(mktemp "${lock_file}.tmp.XXXXXX")"
cleanup() {
    rm -f -- "$lock_tmp"
}
trap cleanup EXIT

jq --arg node "$node" --argjson locked "$prefetched_locked" '
    .nodes[$node].locked as $old
    | .nodes[$node].locked = (
        reduce ($old | keys_unsorted[]) as $key
          ($old;
            if ($locked | has($key)) then .[$key] = $locked[$key] else . end)
        | reduce (($locked | keys_unsorted) - ($old | keys_unsorted))[] as $key
            (. ; .[$key] = $locked[$key])
      )
  ' "$lock_file" >"$lock_tmp"
mv -- "$lock_tmp" "$lock_file"

flake_hash_after="$(sha256sum "$flake_file")"
if [[ "$flake_hash_before" != "$flake_hash_after" ]]; then
    echo "Error: flake.nix changed unexpectedly" >&2
    exit 1
fi

locked_rev="$(jq -er --arg node "$node" '.nodes[$node].locked.rev' "$lock_file")"
locked_nar_hash="$(jq -er --arg node "$node" '.nodes[$node].locked.narHash' "$lock_file")"
printf 'Updated %s (%s):\n' "$input_name" "$node"
printf '  rev:     %s\n' "$locked_rev"
printf '  narHash: %s\n' "$locked_nar_hash"
printf '  lock:    %s\n' "$lock_file"
