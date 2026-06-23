#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq gnused coreutils nix

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/default.nix"

OWNER="mihomo-party-org"
REPO="clash-party"
PNAME="clash-party"

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

base="https://github.com/$OWNER/$REPO/releases/download/$new_tag"
amd64_url="$base/clash-party-linux-${new_version}-amd64.deb"
arm64_url="$base/clash-party-linux-${new_version}-arm64.deb"

echo "prefetching $amd64_url ..." >&2
amd64_hash="$(prefetch_hash "$amd64_url")"
echo "prefetching $arm64_url ..." >&2
arm64_hash="$(prefetch_hash "$arm64_url")"

# version 回写；两个 hash 按 fetchurl 块定位回写（amd64 块在前，arm64 块在后）。
sed -i \
  -e "s|^\(\s*version = \)\"[^\"]*\";|\1\"$new_version\";|" \
  -e "/x86_64-linux = fetchurl {/,/};/ s|^\(\s*hash = \)\"[^\"]*\";|\1\"$amd64_hash\";|" \
  -e "/aarch64-linux = fetchurl {/,/};/ s|^\(\s*hash = \)\"[^\"]*\";|\1\"$arm64_hash\";|" \
  "$PACKAGE_NIX"

echo "$PNAME -> $new_version"
echo "  x86_64-linux.hash  = $amd64_hash"
echo "  aarch64-linux.hash = $arm64_hash"
