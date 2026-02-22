{ config, lib, pkgs, isDarwin, ... }:
{
  # https://github1s.com/nix-community/home-manager/blob/master/modules/services/syncthing.nix
  # https://nix-community.github.io/home-manager/options.xhtml#opt-services.syncthing.enable
  # https://github1s.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/syncthing.nix
  services.syncthing = {
    enable = true;
    guiAddress = "0.0.0.0:8384";
    overrideDevices = false;
    overrideFolders = false;
    settings.options = {
      urAccepted = -1;
    };
  };
}