{ flake, ... }:

final: prev:
let
  lib = final.lib;
in
{
  jadx = prev.jadx.overrideAttrs (oldAttrs: rec {
    version = "1.5.5";
    src = lib.trace "FYI: jadx pinned to ${version}" prev.fetchFromGitHub {
      owner = "skylot";
      repo = "jadx";
      rev = "v${version}";
      hash = lib.fakeHash;
    };
  });
}