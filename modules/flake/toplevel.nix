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
  perSystem = { self', pkgs, ... }: {
    # For 'nix fmt'
    formatter = pkgs.nixpkgs-fmt;
  };
}
