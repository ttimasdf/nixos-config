{ flake, ... }:

final: prev:
let
  lib = final.lib;
in
{
  clash-verge-rev = prev.clash-verge-rev.overrideAttrs (oldAttrs: rec {
    # https://github.com/clash-verge-rev/clash-verge-rev/commits/dev/
    version = "2.4.6";
    src = lib.trace "FYI: clash-verge-rev pinned to ${version}" prev.fetchFromGitHub {
      owner = "clash-verge-rev";
      repo = "clash-verge-rev";
      tag = "v${version}";
      hash = "sha256-s/dUy9vYxdUlAahVPkoOHjoF+WCl3xhJOubZtS1PB5o=";
    };
  });
}
