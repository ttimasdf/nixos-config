{ config, lib, pkgs, isDarwin, ... }:
{
  # enable espanso service will enable `rabit.nixos.gui.espanso-wayland-fix.enable`
  # defined in modules/nixos/gui/espanso-wayland-fix.nix
  services.espanso.enable = false;
  services.espanso.package = pkgs.espanso-wayland;

  services.espanso.configs = {
    default = {
      search_shortcut = "ALT+SHIFT+E";
    };
  };
}
