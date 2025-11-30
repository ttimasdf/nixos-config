{ config, lib, pkgs, isDarwin, ... }:
{
  xdg.configFile."fontconfig/conf.d/10-hm-fonts.conf".force = true;

  /**
    https://wiki.nixos.org/wiki/Fonts#Flatpak_applications_can't_find_system_fonts
    Solution 2, Option 1:
    - Symlink to system fonts at $HOME/.local/share/fonts
    - Allow access to the fonts folder and /nix/store
   */

  # home.file.".local/share/fonts".source = config.lib.file.mkOutOfStoreSymlink "/run/current-system/sw/share/X11/fonts";
}
