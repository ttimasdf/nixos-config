{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
{
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.kitty.enable
  programs.kitty = {
    enable = true;
    font.name = "Maple Mono NF CN";
    enableGitIntegration = true;

    # kitty.conf - kitty https://sw.kovidgoyal.net/kitty/conf/
    settings = {
      kitty_mod = "ctrl+shift"; # default, but to be explicit
      scrollback_lines = 99999;
      # background_opacity = 0.85;
      cursor_trail = 1;

      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "round";
      tab_title_template = "{fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{tab.last_focused_progress_percent}{title}";
      tab_title_max_length = 30;

      notify_on_cmd_finish = "unfocused 10";
    };

    # Mappable actions - kitty https://sw.kovidgoyal.net/kitty/actions/
    keybindings = {
      "ctrl+c" = "copy_or_interrupt"; # default to copy_or_noop
      "kitty_mod+t" = "new_tab_with_cwd"; # default to new_tab
      "ctrl+shift+enter" = "new_window_with_cwd"; # default to new_window
      "kitty_mod+n" = "new_os_window_with_cwd"; # default to new_os_window

      "kitty_mod+p" = "command_palette";
      # "kitty_mod+s" = "launch --stdin-source=@screen_scrollback --type=background sh -c 'cat > ~/Documents/kitty-log/$(date +%Y-%m-%d-%H-%M-%S).log'"; # log current terminal buffer
      "kitty_mod+d" = "detach_window new-tab"; # moves the window into a new tab
      "kitty_mod+f" = "detach_window ask"; # asks which tab to move the window into
      "ctrl+1" = "goto_tab 1";
      "ctrl+2" = "goto_tab 2";
      "ctrl+3" = "goto_tab 3";
      "ctrl+4" = "goto_tab 4";
      "ctrl+5" = "goto_tab 5";
      "ctrl+6" = "goto_tab 6";
      "ctrl+7" = "goto_tab 7";
      "ctrl+8" = "goto_tab 8";
      "ctrl+9" = "goto_tab 9";
      "ctrl+0" = "goto_tab 10";
    };

    # see output of `kitten themes`
    # or https://github.com/kovidgoyal/kitty-themes/tree/master/themes
    themeFile = "Catppuccin-Latte";
  };

  rabit.home.kitty.kitty-new-tab.enable = true;
  # rabit.home.kitty.kitty-new-tab.debug_log.enable = lib.trace "kitty-new-tab.debug_log enabled" true;
  rabit.home.kitty.adaptive-layouts = {
    enable = true;
    portrait.layouts = [
      "stack"
      "vertical"
    ];
    landscape.layouts = [
      "tall"
      "grid"
      "stack"
    ];
  };
  rabit.home.kitty.session.enable = true;
}
