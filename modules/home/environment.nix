{ config, lib, pkgs, isDarwin, ... }:
{
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}
