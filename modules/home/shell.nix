{ ... }:
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
      # Custom ~/.bashrc goes here
      initExtra = ''
        # Set UV cache directory to filesystem-specific location when not on root filesystem
        # This ensures UV (Python package manager) uses appropriate cache location
        # when working on mounted filesystems or external drives
        fs_root=$(df --output=target "$PWD" | tail -n 1)
        if [[ "$fs_root" != "/" && "$fs_root" != "/home" ]]; then
          export UV_CACHE_DIR="$fs_root/.cache/uv"
        fi

        function px(){
          if [ -z "$http_proxy" ]; then
            export http_proxy=http://127.0.0.1:28888 https_proxy=http://127.0.0.1:28888 all_proxy=socks5://127.0.0.1:28888
            echo "Proxy Go"
          else
            unset http_proxy https_proxy all_proxy
            echo "Proxy Unset"
          fi
        }
      '';
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