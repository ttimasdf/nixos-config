{ flake, lib, config, pkgs, ... }:
let
  inherit (flake) self;
  inherit (self) overlays rabit-lib;
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
