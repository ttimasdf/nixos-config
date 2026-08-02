{ flake, ... }:

let
  inherit (flake.inputs) self;
in
{
  imports = [
    self.nixosModules.common
    flake.inputs.nixos-wsl.nixosModules.default
    ./configuration.nix
  ];
}
