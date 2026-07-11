{ config, lib, pkgs, isDarwin, ... }:
{
  services.espanso.enable = false;
  services.espanso.package = pkgs.espanso-wayland;

  services.espanso.configs = {
    default = {
      search_shortcut = "ALT+SHIFT+E";
    };
  };
}
