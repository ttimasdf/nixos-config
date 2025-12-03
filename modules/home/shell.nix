{ ... }:
{
  home.shellAliases = {
    g = "git";
    lg = "lazygit";
  };

  home.shell = {
    enableShellIntegration = true;
  };

  programs = {
    # on macOS, you probably don't need this
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
      # Custom ~/.bashrc goes here
      initExtra = ''
        # Set UV cache directory to filesystem-specific location when not on root filesystem
        # This ensures UV (Python package manager) uses appropriate cache location
        # when working on mounted filesystems or external drives
        fs_root=$(df --output=target "$PWD" | tail -n 1)
        if [[ "$fs_root" != "/" && "$fs_root" != "/home" ]]; then
          export UV_CACHE_DIR="$fs_root/.cache/uv"
        fi
      '';
    };

    # For macOS's default shell.
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      enableCompletion = true;

      # zsh - What should/shouldn't go in .zshenv, .zshrc, .zlogin, .zprofile, .zlogout? - Unix & Linux Stack Exchange
      # https://unix.stackexchange.com/questions/71253/what-should-shouldnt-go-in-zshenv-zshrc-zlogin-zprofile-zlogout

      # Custom ~/.zshenv goes here
      envExtra = ''
        # Set UV cache directory to filesystem-specific location when not on root filesystem
        # This ensures UV (Python package manager) uses appropriate cache location
        # when working on mounted filesystems or external drives
        fs_root=$(df --output=target "$PWD" | tail -n 1)
        if [[ "$fs_root" != "/" && "$fs_root" != "/home" ]]; then
          export UV_CACHE_DIR="$fs_root/.cache/uv"
        fi
      '';
      # Custom ~/.zshrc goes here
      initContent = ''
        bindkey -e
      '';
      # Custom ~/.zprofile goes here
      profileExtra = ''
      '';
      # Custom ~/.zlogin goes here
      loginExtra = ''
      '';
      # Custom ~/.zlogout goes here
      logoutExtra = ''
      '';
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