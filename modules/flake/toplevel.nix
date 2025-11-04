# Top-level flake glue to get our configuration working
{ inputs, ... }:

{
  imports = [
    inputs.nixos-unified.flakeModules.default
    inputs.nixos-unified.flakeModules.autoWire
  ];
  # https://flake.parts/options/flake-parts#opt-debug
  # debug = true;
  perSystem = { self', pkgs, ... }: {
    # For 'nix fmt'
    formatter = pkgs.nixpkgs-fmt;
  };
}
