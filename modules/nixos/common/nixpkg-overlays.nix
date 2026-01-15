{ flake, lib, config, pkgs, ... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;
  # Load all overlays from the overlays directory
  overlays =
    rabit-lib.forAllNixFiles "${self}/overlays"
      (fn: import fn {inherit flake lib config;});

  packagesPath = self + "/packages";
  packages =
    final: prev:
      rabit-lib.forAllNixFiles "${self}/packages"
        (fn: lib.callPackageWith final fn { });

in
{
  # Map the list of file paths to a list of overlay functions
  nixpkgs.overlays = (builtins.attrValues overlays) ++ [ packages ];
}
