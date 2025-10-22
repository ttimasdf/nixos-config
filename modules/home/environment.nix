{ config, lib, pkgs, isDarwin, ... }:
{
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
  home.sessionVariables = {
    GDK_SCALE = "2";
  };
}
