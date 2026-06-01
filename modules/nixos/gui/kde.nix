{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.rabit.nixos.gui.kde;
in
{
  options.rabit.nixos.gui.kde.enable = lib.mkEnableOption "Desktop Environment: KDE";
  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.desktopManager.plasma6.enable = true;

    environment.systemPackages =
      with pkgs;
      with kdePackages;
      [
        partitionmanager
        ksystemlog
        plasma-systemmonitor
        sddm-kcm
        ksshaskpass

        discover
        kcalc
        kclock

        filelight
        spacebar
        kdeconnect-kde
        qttools
        # k3b # waiting for PR#475899

        wayland-utils
        wl-clipboard
        xclip
      ]
      ++ lib.optionals (config.services.flatpak.enable) [
        flatpak-kcm
      ];
  };
}
