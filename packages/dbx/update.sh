#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq gnused coreutils nix

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/default.nix"

OWNER="t8y2"
REPO="dbx"
PNAME="dbx"

nix_cmd=(
  nix
  --extra-experimental-features
  "nix-command flakes"
)

# 抓取 url 对应文件的 SRI hash（nix prefetch，不落 store link）。
prefetch_hash() {
  local url="$1"
  "${nix_cmd[@]}" store prefetch-file --json --hash-type sha256 "$url" |
    jq --raw-output '.hash'
}

if [[ $# -gt 1 ]]; then
  echo "usage: $0 [version-or-tag]" >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  requested="$1"
  if [[ "$requested" == v* ]]; then
    new_tag="$requested"
  else
    new_tag="v$requested"
  fi
else
  new_tag="$(
    curl --fail --silent --show-error \
      "https://api.github.com/repos/$OWNER/$REPO/releases/latest" |
      jq --raw-output '.tag_name'
  )"
fi

if [[ -z "$new_tag" || "$new_tag" == "null" ]]; then
  echo "failed to determine the latest GitHub release tag" >&2
  exit 1
fi

if [[ "$new_tag" != v* ]]; then
  echo "unexpected release tag format: $new_tag (expected v<version>)" >&2
  exit 1
fi

new_version="${new_tag#v}"
current_version="$(sed -n 's/^[[:space:]]*version = "\([^"]*\)";/\1/p' "$PACKAGE_NIX" | head -n1)"

if [[ "$current_version" == "$new_version" ]]; then
  echo "$PNAME is already at $new_version"
  exit 0
fi

url="https://github.com/$OWNER/$REPO/releases/download/$new_tag/DBX_${new_version}_amd64.deb"

echo "prefetching $url ..." >&2
hash="$(prefetch_hash "$url")"

# version 与 .deb hash 回写。注意 hash 行在 `src = fetchurl { ... };` 块内，
# 用块定位避免误伤其它 fetchurl 块。
sed -i \
  -e "s|^\(\s*version = \)\"[^\"]*\";|\1\"$new_version\";|" \
  -e "/src = fetchurl {/,/};/ s|^\(\s*hash = \)\"[^\"]*\";|\1\"$hash\";|" \
  "$PACKAGE_NIX"

echo "$PNAME -> $new_version"
echo "  src.hash = $hash"
