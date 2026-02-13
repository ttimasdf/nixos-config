{ config, lib, pkgs, isDarwin, ... }:
{
  # https://nix-community.github.io/home-manager/options.xhtml#opt-services.syncthing.enable
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