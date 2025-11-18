{ config, lib, pkgs, isDarwin, ... }:
{
  programs.kitty = {
    enable = true;
    # font.name = "Maple Mono NF CN";
    settings = {
      scrollback_lines = 10000;
      # background_opacity = 0.85;
      cursor_trail = 1;
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
    };
    themeFile = "Catppuccin-Latte";
  };
}
