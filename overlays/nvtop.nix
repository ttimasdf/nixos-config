{ flake, ... }:

final: prev:
let
  inherit (flake.inputs) nixpkgs;
in
{
  nvtopPackages = prev.nvtopPackages // {
    nvidia-intel = final.callPackage "${nixpkgs}/pkgs/tools/system/nvtop/build-nvtop.nix" { intel = true; nvidia = true; };
  };
}
