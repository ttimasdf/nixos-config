{ config, lib, pkgs, isDarwin, ... }:
{
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.distrobox.enable
  programs.distrobox = {
    enable = true;
  };

  home.packages = with pkgs; [
    distrobox-tui
  ];
}
