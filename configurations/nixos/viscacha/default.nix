# See /modules/nixos/* for actual settings
# This file is just *top-level* configuration.
{ flake, ... }:

let
  inherit (flake.inputs) self nixos-hardware nur private-module;
in
{
  imports = [
    nur.modules.nixos.default
    nixos-hardware.nixosModules.common-cpu-intel
    nixos-hardware.nixosModules.common-pc-laptop
    nixos-hardware.nixosModules.common-pc-ssd
    # common-gpu-nvidia imports https://github.com/NixOS/nixos-hardware/blob/master/common/gpu/nvidia/prime.nix
    nixos-hardware.nixosModules.common-gpu-nvidia
    nixos-hardware.nixosModules.common-hidpi
    self.nixosModules.common
    private-module.nixosModules.all
    self.nixosModules.programs
    self.nixosModules.secure-boot
    self.nixosModules.gui
    self.nixosModules.winapps
    self.nixosModules.images
    ./configuration.nix
  ];
}
