{ flake, ... }:

final: prev:
let
  lib = final.lib;
in
{
  podman-compose = prev.podman-compose.overrideAttrs (oldAttrs: rec {
    # we need --wait from https://github.com/containers/podman-compose/pull/1356
    version = "1.6.0";
    src = lib.trace "FYI: podman-compose pinned to ${version}" prev.fetchFromGitHub {
      owner = "containers";
      repo = "podman-compose";
      rev = "v${version}";
      hash = "sha256-zkXLZfYWpIaQYoUU7GcGnkuTBmhzpJkyojbzFuTR5FI=";
    };
  });
}
