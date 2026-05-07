# Top-level flake glue to get our configuration working
{ inputs, ... }:

{
  imports = [
    inputs.nixos-unified.flakeModules.default
    # https://github.com/srid/nixos-unified/blob/master/nix/modules/flake-parts/autowire.nix
    inputs.nixos-unified.flakeModules.autoWire
  ];
  # https://flake.parts/options/flake-parts#opt-debug
  # debug = true;
  perSystem = { lib, pkgs, system, ... }:
    let
      stablePkgs = import inputs.nixpkgs-stable {
        inherit system;
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [ "qtwebengine-5.15.19" ];
        };
      };
    in
    {
      # For 'nix fmt'
      formatter = pkgs.nixpkgs-fmt;

      packages.unicom-cloud-desktop = lib.mkForce (pkgs.callPackage ../../packages/unicom-cloud-desktop { inherit stablePkgs; });
    };
}
