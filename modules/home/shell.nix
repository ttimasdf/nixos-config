{ lib, config, osConfig, ... }:
let
  oscfg = osConfig.rabit.nixos;

  # Environment variables for ALL shells (login, interactive, scripts)
  # bash: ~/.profile (via profileExtra, sourced by login shells)
  # zsh: ~/.zshenv (via envExtra, sourced by all zsh instances)
  allShellExtra = ''
    # Set UV cache directory to filesystem-specific location when not on root filesystem
    # This ensures UV (Python package manager) uses appropriate cache location
    # when working on mounted filesystems or external drives
    _fs_root=$(df --output=target "$PWD" | tail -n 1)
    if [[ "$_fs_root" != "/" && "$_fs_root" != "/home" ]]; then
      export UV_CACHE_DIR="$_fs_root/.cache/uv"
    fi
    unset _fs_root
  '' + lib.optionalString config.programs.distrobox.enable ''
    # Set environment variables inside distrobox
    if [[ -n "$DISTROBOX_ENTER_PATH" ]]; then
      export PATH="$HOME/.local/bin:$PATH"
    fi
  '';

  # Interactive shell config: aliases, functions, key bindings
  # bash: ~/.bashrc (via initExtra)
  # zsh: ~/.zshrc (via initContent)
  interactiveShellExtra = lib.optionalString (oscfg.http_proxy != null) ''
    # Toggle proxy on/off
    function px(){
      if [ -z "$http_proxy" ]; then
        export http_proxy="${oscfg.http_proxy}" https_proxy="${oscfg.http_proxy}" all_proxy="${oscfg.http_proxy}"
        echo -e "[proxy] \e[32menabled\e[0m, set to $http_proxy"
      else
        unset http_proxy https_proxy all_proxy
        echo -e "[proxy] \e[31mdisabled\e[0m"
      fi
    }
  '' + lib.optionalString config.programs.yazi.enable ''
    # y for yazi - change directory on exit
    function y() {
      local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
      yazi "$@" --cwd-file="$tmp"
      IFS= read -r -d "" cwd < "$tmp"
      [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
      rm -f -- "$tmp"
    }
  '';

  # Login shell config (runs once at login)
  # bash: ~/.profile (via profileExtra)
  # zsh: ~/.zprofile (via profileExtra)
  loginShellExtra = '''';
in
{
  home.shellAliases = {
    g = "git";
    lg = "lazygit";
    clip = "wl-copy";
  };

  home.shell = {
    enableShellIntegration = true;
  };

  programs = {
    bash = {
      enable = true;

      historyFileSize = 100000;
      historySize = 50000;
      historyControl = [
        "ignoredups"
        "erasedups"
      ];
      historyIgnore = [
        "ls"
        "cd"
        "exit"
      ];
      # Custom ~/.profile content (sourced by login shells)
      profileExtra = loginShellExtra;

      # Custom ~/.bashrc (before interactive shell check)
      bashrcExtra = allShellExtra;

      # Custom ~/.bashrc (after interactive shell check)
      initExtra = interactiveShellExtra;
    };

    zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      enableCompletion = true;

      history = {
        append = true;
        size = 100000;
        save = 100000;

        expireDuplicatesFirst = true;
        ignoreAllDups = true;
        saveNoDups = true;
        # findNoDups = true;
      };

      # zsh - What should/shouldn't go in .zshenv, .zshrc, .zlogin, .zprofile, .zlogout? - Unix & Linux Stack Exchange
      # https://unix.stackexchange.com/questions/71253/what-should-shouldnt-go-in-zshenv-zshrc-zlogin-zprofile-zlogout

      # Custom ~/.zshenv goes here
      envExtra = allShellExtra;
      # Custom ~/.zshrc goes here
      initContent = ''
        bindkey -e
      '' + interactiveShellExtra;
      # Custom ~/.zprofile goes here
      profileExtra = loginShellExtra;
    };

    # Type `z <pat>` to cd to some directory
    zoxide.enable = true;

    # Better shell prompt!
    starship = {
      enable = true;
      settings = {
        username = {
          style_user = "blue bold";
          style_root = "red bold";
          format = "[$user]($style) ";
          disabled = false;
          show_always = true;
        };
        hostname = {
          ssh_only = false;
          ssh_symbol = "🌐 ";
          format = "on [$hostname](bold red) ";
          trim_at = ".local";
          disabled = false;
        };
      };
    };
  };
}
