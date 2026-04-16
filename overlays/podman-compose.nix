{ flake, ... }:

final: prev:
let
  lib = final.lib;
in
{
  podman-compose = prev.podman-compose.overrideAttrs (oldAttrs: rec {
    # we need --wait from https://github.com/containers/podman-compose/pull/1356
    version = "1-unstable-2026-04-16";
    src = lib.trace "FYI: podman-compose pinned to ed3ec99" prev.fetchFromGitHub {
      owner = "containers";
      repo = "podman-compose";
      rev = "ed3ec99699f692de5440c929ee9e7bfb116871c2";
      hash = "sha256-OxuWnyxhT6sjH6K5b+7KTx4z8DLLn5sLFUDto9Pa6EY=";
    };
  });
}
