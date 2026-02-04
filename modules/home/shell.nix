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
    # Usage: px [port|ip:port|url]
    #   px          - toggle proxy using default (${oscfg.http_proxy})
    #   px 7890     - set proxy to http://localhost:7890
    #   px 1.2.3.4:8080 - set proxy to http://1.2.3.4:8080
    #   px http://... - set proxy to the given URL directly
    function px(){
      local proxy_url=""
      if [[ -n "$1" ]]; then
        if [[ "$1" =~ ^[0-9]+$ ]]; then
          # Argument is a port number
          proxy_url="http://localhost:$1"
        elif [[ "$1" == *"://"* ]]; then
          # Argument is a full URL (contains ://)
          proxy_url="$1"
        else
          # Argument is host:port or ip:port format
          proxy_url="http://$1"
        fi
        export http_proxy="$proxy_url" https_proxy="$proxy_url" all_proxy="$proxy_url"
        echo -e "[proxy] \e[32menabled\e[0m, set to $http_proxy"
      elif [ -z "$http_proxy" ]; then
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
  '' + lib.optionalString config.programs.fzf.enable ''
    # Re-source fzf shell integration for fzf < 0.66
    # There's a breaking change (`toggle-raw` feature) in fzf 0.66.0
    if [[ -n "$DISTROBOX_ENTER_PATH" ]] && command -v fzf &>/dev/null; then
      _fzf_version=$(fzf --version | awk '{print $1}')
      _fzf_major=''${_fzf_version%%.*}
      _fzf_minor=''${_fzf_version#*.}
      _fzf_minor=''${_fzf_minor%%.*}
      if [[ "$_fzf_major" -eq 0 && "$_fzf_minor" -lt 66 ]]; then
        echo -e "\e[33m[fzf] Warning: fzf version $_fzf_version < 0.66, re-sourcing shell integration\e[0m" >&2
        if [[ -n "$BASH_VERSION" ]]; then
          source <(fzf --bash)
        elif [[ -n "$ZSH_VERSION" ]]; then
          source <(fzf --zsh)
        fi
      fi
      unset _fzf_version _fzf_major _fzf_minor
    fi
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
