{ config, lib, pkgs, isDarwin, ... }:
{
  xdg.configFile."fontconfig/conf.d/10-hm-fonts.conf".force = true;
}
