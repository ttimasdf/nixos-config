# Minimal hardware configuration for brisling
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    # (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

 nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
