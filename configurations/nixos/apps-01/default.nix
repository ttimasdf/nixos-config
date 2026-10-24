# apps-01 — application container host (unprivileged NixOS LXC). Appliance wiring.
{ flake, ... }:

let
  inherit (flake.inputs) self private-module;
in
{
  imports = [
    self.nixosModules.common
    private-module.nixosModules.all
    ./configuration.nix
  ];
}
