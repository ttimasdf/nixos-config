# See /modules/nixos/* for actual settings
# This file is just *top-level* configuration.
{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self nixos-hardware;
in
{
  imports = [
    nixos-hardware.nixosModules.lenovo-legion-16irx9h
    self.nixosModules.default
    self.nixosModules.secure-boot
    self.nixosModules.gui
    ./configuration.nix
  ];
}
