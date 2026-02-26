{ config, lib, pkgs, isDarwin, ... }:
{
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.kitty.enable
  programs.kitty = {
    enable = true;
    # font.name = "Maple Mono NF CN";
    enableGitIntegration = true;

    # kitty.conf - kitty https://sw.kovidgoyal.net/kitty/conf/
    settings = {
      scrollback_lines = 10000;
      # background_opacity = 0.85;
      cursor_trail = 1;

      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "round";
      tab_title_template = "{fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{tab.last_focused_progress_percent}{title}";
      tab_title_max_length  = 30;
    };

    # Mappable actions - kitty https://sw.kovidgoyal.net/kitty/actions/
    keybindings = {
      # "ctrl+c" = "copy_or_interrupt";  # default to copy_or_noop
      "ctrl+shift+enter" = "new_window_with_cwd";  # default to new_window
      "alt+shift+1" = "goto_tab 1";
      "alt+shift+2" = "goto_tab 2";
      "alt+shift+3" = "goto_tab 3";
      "alt+shift+4" = "goto_tab 4";
      "alt+shift+5" = "goto_tab 5";
      "alt+shift+6" = "goto_tab 6";
      "alt+shift+7" = "goto_tab 7";
      "alt+shift+8" = "goto_tab 8";
      "alt+shift+9" = "goto_tab 9";
      "alt+shift+0" = "goto_tab 10";
    };

    # see output of `kitten themes`
    # or https://github.com/kovidgoyal/kitty-themes/tree/master/themes
    themeFile = "Catppuccin-Latte";
  };

  rabit.home.kitty.kitty-in-tab.enable = true;
}
