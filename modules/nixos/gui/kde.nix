{ config, lib, pkgs, ... }:

let
  cfg = config.rabit.nixos.gui.kde;
in {
  options.rabit.nixos.gui.kde.enable = lib.mkEnableOption "Desktop Environment: KDE";
  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
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

      kdePackages.filelight
      kdePackages.spacebar
      # kdePackages.k3b # waiting for PR#475899

      wayland-utils
      wl-clipboard
      xclip
    ] ++ lib.optionals (config.services.flatpak.enable) [
      kdePackages.flatpak-kcm
    ];
  };
}
