{ config, lib, pkgs, ... }:

let
  cfg = config.rabit.modules.gui.gnome;
in {
  options.rabit.modules.gui.gnome.enable = lib.mkEnableOption "Desktop Environment: Gnome";
  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    environment.systemPackages = with pkgs; [
      pkgs.gnome-tweaks
    ];
  };
}
