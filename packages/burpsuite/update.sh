#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq xxd gnused diffutils
set -eu -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

json_file="$(mktemp --suffix=.json)"

curl -s 'https://portswigger.net/burp/releases/data' |
  jq -r '
      [[
        .ResultSet.Results[]
        | select(
            (.categories | sort) == (["Professional","Community"] | sort)
            and .releaseChannels == ["Stable"]
          )
      ][0].builds[]
      | select(.ProductPlatform == "Jar")
    ]' >"$json_file"

version=$(jq -r '.[0].Version' "$json_file")

comm_hex=$(jq -r '.[] | select(.ProductId=="community") .Sha256Checksum' "$json_file")
pro_hex=$(jq -r '.[] | select(.ProductId=="pro") .Sha256Checksum' "$json_file")

comm_sri="sha256-$(printf %s "$comm_hex" | xxd -r -p | base64 -w0)"
pro_sri="sha256-$(printf %s "$pro_hex" | xxd -r -p | base64 -w0)"

sed -i \
  -e "s|^\(\s*version = \)\"[^\"]*\";|\1\"$version\";|" \
  -e "/productName = \"community\"/,/hash =/ {
        s|sha256-[^\"]*|$comm_sri|
     }" \
  -e "/productName = \"pro\"/,/hash =/ {
        s|sha256-[^\"]*|$pro_sri|
     }" \
  $SCRIPT_DIR/package.nix

echo "burpsuite → $version"
echo "  community: $comm_sri"
echo "  pro      : $pro_sri"

rm "$json_file"
