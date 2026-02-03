# See /modules/nixos/* for actual settings
# This file is just *top-level* configuration.
{ flake, ... }:

let
  inherit (flake.inputs) self nixos-hardware nur private-module;
in
{
  imports = [
    nur.modules.nixos.default
    nixos-hardware.nixosModules.lenovo-thinkpad-x1-12th-gen
    self.nixosModules.common
    private-module.nixosModules.all
    self.nixosModules.programs
    self.nixosModules.secure-boot
    self.nixosModules.gui
    self.nixosModules.winapps
    ./configuration.nix
  ];
}
