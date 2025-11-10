{ config, lib, pkgs, isDarwin, ... }:
{
  services.espanso.enable = true;
  # use with rabit.nixos.gui.espanso-wayland-fix.enable
  services.espanso.package = pkgs.espanso-wayland;

  services.espanso.configs = {
    default = {
      search_shortcut = "ALT+SHIFT+E";
    };
  };
}
