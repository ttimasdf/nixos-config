# edge-01 — zone-fabric appliance VM. Top-level wiring kept minimal:
# no NUR/programs/images (desktop-oriented), no home-manager users.
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
