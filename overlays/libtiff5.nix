# The current libtiff version is incompatible with unicom-cloud-desktop,
# which requires libtiff v4.4.0 (ABI 5).
{ flake, ... }:

final: prev:
let
  pkgs-libtiff-abi5 = import (fetchTarball {
    # the latest commit with libtiff 4.4.0 in nixpkgs, which is before the ABI bump.
    # https://github.com/NixOS/nixpkgs/tree/ccef3ab7d8762c6e5c75688dfd2d0850d9469a33/pkgs/development/libraries/libtiff
    name = "nixpkgs-libtiff-abi5";
    url = "https://github.com/NixOS/nixpkgs/archive/ccef3ab7d8762c6e5c75688dfd2d0850d9469a33.tar.gz";
    sha256 = "sha256:0b4npkdybcq2ihrya5rp6l3qdaa6s2w6v58cqa2l1ychr5z58vh1";
  }) {
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  libtiff-abi5 = pkgs-libtiff-abi5.libtiff;
}
