{ pkgs
, isDarwin
, ...
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

      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      active_tab_font_style = "bold";
      tab_title_template = "{fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{tab.last_focused_progress_percent}{custom}";
      tab_title_max_length = 16;

      notify_on_cmd_finish = "unfocused 10";
    };

    # Named action: opens the current window's working directory in VS Code.
    # Also available from the command palette (kitty_mod+m).
    # `--cwd=last_reported` uses the shell's last OSC 7 cwd report: the directory
    # the current program (e.g. pi) was launched from. Unlike `--cwd=current`,
    # it is immune to resident helper daemons (e.g. wl-copy's) that linger in
    # the window's foreground process group with cwd=/ and hijack kitty's cwd
    # resolution (kitty picks the newest process in the group).
    actionAliases.open_in_vscode = "launch --type=background --cwd=last_reported code .";

    # Mappable actions - kitty https://sw.kovidgoyal.net/kitty/actions/
    keybindings = {
      "ctrl+c" = "copy_or_interrupt"; # default to copy_or_noop
      # *_with_cwd actions resolve `--cwd=current`: the cwd of the NEWEST process
      # in the foreground process group. While a TUI (pi) runs, resident helper
      # daemons it spawned (wl-copy's, cwd=/) hijack that resolution, so new
      # tabs/windows/os_windows would open in /. Use the shell's last OSC 7 cwd
      # report instead.
      "kitty_mod+t" = "launch --type=tab --cwd=last_reported"; # default to new_tab
      "ctrl+shift+enter" = "launch --type=window --cwd=last_reported"; # default to new_window
      "kitty_mod+n" = "launch --type=os-window --cwd=last_reported"; # default to new_os_window

      "kitty_mod+m" = "command_palette";
      # "kitty_mod+s" = "launch --stdin-source=@screen_scrollback --type=background sh -c 'cat > ~/Documents/kitty-log/$(date +%Y-%m-%d-%H-%M-%S).log'"; # log current terminal buffer
      "kitty_mod+d" = "detach_window new-tab"; # moves the window into a new tab
      "kitty_mod+f" = "detach_window ask"; # asks which tab to move the window into
      "kitty_mod+i" = "open_in_vscode"; # free in kitty 0.48 defaults; i for IDE
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

  rabit.home.kitty.new-tab.enable = true;
  # rabit.home.kitty.new-tab.debug_log.enable = lib.trace "kitty-new-tab.debug_log enabled" true;
  rabit.home.kitty.adaptive-layouts = {
    enable = true;
    portrait.layouts = [
      "vertical"
      "stack"
    ];
    landscape.layouts = [
      "tall"
      "grid"
      "stack"
    ];
  };
  rabit.home.kitty.session-snapshot.enable = true;
  rabit.home.kitty.session-snapshot.pi-resume.enable = true;
  rabit.home.kitty.wl-copy-shim.enable = true;
}
