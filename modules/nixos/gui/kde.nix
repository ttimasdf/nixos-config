{ config, lib, pkgs, ... }:
{
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = with pkgs; [
    kdePackages.partitionmanager
    kdePackages.ksystemlog
    kdePackages.plasma-systemmonitor
    kdePackages.sddm-kcm

    kdePackages.discover
    kdePackages.kcalc
    kdePackages.kclock

    wayland-utils
    wl-clipboard
    xclip
  ] ++ lib.optionals (config.services.flatpak.enable) [
    kdePackages.flatpak-kcm
  ];
}
