# edge-01 — router appliance: no NUR, programs, images or home-manager users.
{ flake, ... }:

let
  inherit (flake.inputs) self private-module;
in
{
  imports = [
    self.nixosModules.common
    private-module.nixosModules.all
    ./hardware-configuration.nix
    ./configuration.nix
  ];
}
