{ flake, lib, config, pkgs, ... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;
  inherit (flake.inputs) private-module;

  packages =
    final: prev:
      rabit-lib.forAllNixFiles "${self}/packages"
        (fn: lib.callPackageWith final fn { });
  privatePackages = final: prev: private-module.packages;
in
{
  # Map the list of file paths to a list of overlay functions
  nixpkgs.overlays =
    (builtins.attrValues self.overlays)
    ++ (builtins.attrValues private-module.overlays)
    ++ [ packages privatePackages ];
}
