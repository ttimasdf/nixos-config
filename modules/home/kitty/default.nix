{ config
, lib
, pkgs
, isDarwin
, ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkAfter
    types
    optional
    assertMsg
    ;
  cfg = config.rabit.home.kitty.kitty-new-tab;
  adaptive-layouts-cfg = config.rabit.home.kitty.adaptive-layouts;
  session-cfg = config.rabit.home.kitty.session;
  session-pi-resume-cfg = config.rabit.home.kitty.session.pi-resume;
  kitty-package =
    if config.programs.kitty.package != null then config.programs.kitty.package else pkgs.kitty;
  needs-remote-control = cfg.enable || session-cfg.enable;

  flake8IgnoredErrors = [
    "E111" # indentation is not a multiple of 4
    "E114" # indentation is not a multiple of 4 (comment)
    "E121" # continuation line under-indented for hanging indent
    "E501" # line too long
    "E203" # whitespace before ':' - conflicts with black's slice formatting,
    # which is what the scripts in scripts/session/ are formatted with
  ];

  kitty-is-cmd-allowed-source =
    builtins.replaceStrings
      [ "@libnotify@" "@log_level@" ]
      [
        (lib.getExe pkgs.libnotify)
        (if cfg.debug_log.enable then "DEBUG" else "INFO")
      ]
      (builtins.readFile ./scripts/kitty_is_cmd_allowed.py);

  adaptive-layouts-source =
    builtins.replaceStrings
      [ "@portrait_layouts_json@" "@landscape_layouts_json@" ]
      [
        (builtins.toJSON adaptive-layouts-cfg.portrait.layouts)
        (builtins.toJSON adaptive-layouts-cfg.landscape.layouts)
      ]
      (builtins.readFile ./scripts/adaptive_layouts.py);

  tab-bar-source = builtins.readFile ./scripts/tab_bar.py;

  kitty-session-bash-completion = builtins.readFile ./scripts/session/kitty_session.bash;
  kitty-session-zsh-completion = builtins.readFile ./scripts/session/_kitty-session;
  kitty-session-fish-completion = builtins.readFile ./scripts/session/kitty_session.fish;

  # Shell hooks that resume a Pi session recorded by `kitty-session backup`.
  # The env var is consumed by the interactive shell that a snapshot launches.
  pi-resume-env-var = session-pi-resume-cfg.envVar;
  pi-resume-command = session-pi-resume-cfg.command;

  # Runs in .zshenv for every zsh (and early in .bashrc): refuse to resume from
  # a non-interactive shell, warn, and drop the marker.
  piResumeGuard = ''
    if [ -n "''${${pi-resume-env-var}:-}" ]; then
      case $- in
        *i*) ;;
        *)
          printf '%s\n' "${pi-resume-env-var}=''${${pi-resume-env-var}} ignored: non-interactive shell" >&2
          unset ${pi-resume-env-var}
          ;;
      esac
    fi
  '';

  # Runs at the end of the interactive rc: hand off to Pi and keep the shell.
  piResumeDoResume = ''
    if [ -n "''${${pi-resume-env-var}:-}" ]; then
      _pi_resume_session="''${${pi-resume-env-var}}"
      unset ${pi-resume-env-var}
      if command -v ${pi-resume-command} >/dev/null 2>&1; then
        ${pi-resume-command} --session "$_pi_resume_session"
      else
        printf '%s\n' "${pi-resume-command} not found; session $_pi_resume_session not resumed" >&2
      fi
      unset _pi_resume_session
    fi
  '';

  kitty-session =
    let
      name = "kitty-session";
    in
    pkgs.writers.writePython3Bin name
      {
        flakeIgnore = flake8IgnoredErrors;
        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          "${lib.makeBinPath [ pkgs.fzf ]}"
        ];
      }
      (
        builtins.replaceStrings
          [ "@kitty@" "@resume_env_var@" ]
          [
            (lib.getExe kitty-package)
            session-pi-resume-cfg.envVar
          ]
          (builtins.readFile ./scripts/session/kitty_session.py)
      );

  kitty-new-tab =
    let
      name = "kitty-new-tab";
      script =
        pkgs.writers.writePython3Bin name
          {
            libraries = with pkgs.python3Packages; [ systemd-python ];
            flakeIgnore = flake8IgnoredErrors;
            makeWrapperArgs = [
              "--prefix"
              "PATH"
              ":"
              "${lib.makeBinPath [ pkgs.libnotify ]}"
            ];
          }
          (
            builtins.replaceStrings
              [ "@name@" "@log_level@" ]
              [
                name
                (if cfg.debug_log.enable then "DEBUG" else "INFO")
              ]
              (builtins.readFile ./scripts/kitty_new_tab.py)
          );
      desktopItem = pkgs.makeDesktopItem {
        inherit name;
        desktopName = "Kitty New-Tab Handler";
        genericName = "Terminal emulator";
        comment = "Open a new tab in Kitty";
        icon = "kitty";
        startupWMClass = "kitty";
        exec = "${script}/bin/${name}";
        tryExec = name;
        categories = [
          "System"
          "TerminalEmulator"
        ];
        startupNotify = true;
        extraConfig = {
          X-TerminalArgExec = "--";
          X-TerminalArgTitle = "--title";
          X-TerminalArgAppId = "--class";
          X-TerminalArgDir = "--working-directory";
          X-TerminalArgHold = "--hold";
        };
        noDisplay = true;
        mimeTypes = [
          "MimeType=image/*"
          "application/x-sh"
          "application/x-shellscript"
          "inode/directory"
          "text/*"
          "x-scheme-handler/kitty"
          "x-scheme-handler/ssh"
        ];
      };
    in
    pkgs.symlinkJoin {
      name = "${name}-combined";
      paths = [
        script
        desktopItem
      ];
    };
in
{
  options.rabit.home.kitty.kitty-new-tab = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable kitty-new-tab, a script that opens new tabs in an existing Kitty window
        instead of launching a new Kitty instance.
      '';
    };

    debug_log = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable debug logging for kitty-new-tab and kitty-is-cmd-allowed scripts.
        '';
      };
    };
  };

  options.rabit.home.kitty.adaptive-layouts = {
    enable = mkEnableOption "adaptive Kitty layout profiles based on OS window orientation";

    portrait.layouts = mkOption {
      type = types.listOf types.str;
      default = [
        "vertical"
        "stack"
      ];
      description = "Layouts enabled when a Kitty OS window is taller than it is wide.";
    };

    landscape.layouts = mkOption {
      type = types.listOf types.str;
      default = [
        "tall"
        "grid"
        "stack"
      ];
      description = "Layouts enabled when a Kitty OS window is at least as wide as it is tall.";
    };
  };

  options.rabit.home.kitty.session.enable =
    mkEnableOption "Kitty session backup and restore commands";

  options.rabit.home.kitty.session.pi-resume = {
    enable = mkEnableOption "resuming Pi sessions recorded in Kitty session snapshots";

    envVar = mkOption {
      type = types.str;
      default = "PI_RESUME_SESSION_ID";
      description = ''
        Environment variable set by a restored Kitty session window. The
        interactive shell consumes it to resume the recorded Pi session.
      '';
    };

    command = mkOption {
      type = types.str;
      default = "pi";
      description = "Command used to resume a recorded Pi session.";
    };
  };

  config = mkMerge [
    {
      assertions = [
        {
          assertion = cfg.enable -> config.programs.kitty.enable;
          message = "rabit.home.kitty.kitty-new-tab.enable requires programs.kitty.enable to be true";
        }
        {
          assertion = adaptive-layouts-cfg.enable -> config.programs.kitty.enable;
          message = "rabit.home.kitty.adaptive-layouts.enable requires programs.kitty.enable to be true";
        }
        {
          assertion = session-cfg.enable -> config.programs.kitty.enable;
          message = "rabit.home.kitty.session.enable requires programs.kitty.enable to be true";
        }
        {
          assertion = session-pi-resume-cfg.enable -> session-cfg.enable;
          message = "rabit.home.kitty.session.pi-resume.enable requires rabit.home.kitty.session.enable";
        }
        {
          assertion = adaptive-layouts-cfg.enable -> adaptive-layouts-cfg.portrait.layouts != [ ];
          message = "rabit.home.kitty.adaptive-layouts.portrait.layouts must not be empty";
        }
        {
          assertion = adaptive-layouts-cfg.enable -> adaptive-layouts-cfg.landscape.layouts != [ ];
          message = "rabit.home.kitty.adaptive-layouts.landscape.layouts must not be empty";
        }
      ];
    }
    (mkIf config.programs.kitty.enable {
      xdg.configFile."kitty/tab_bar.py".text = tab-bar-source;
    })
    (mkIf (config.programs.kitty.enable && needs-remote-control) {
      programs.kitty.settings = {
        listen_on = "unix:\${XDG_RUNTIME_DIR}/kitty-rc";
        allow_remote_control = "password";
      };
      programs.kitty.extraConfig = mkAfter ''
        remote_control_password "" kitty_is_cmd_allowed.py
      '';
      xdg.configFile."kitty/kitty_is_cmd_allowed.py".text = kitty-is-cmd-allowed-source;
    })
    (mkIf (config.programs.kitty.enable && cfg.enable) {
      home.packages = [ kitty-new-tab ];
    })
    (mkIf (config.programs.kitty.enable && adaptive-layouts-cfg.enable) {
      programs.kitty.extraConfig = mkAfter ''
        watcher adaptive_layouts.py
      '';
      xdg.configFile."kitty/adaptive_layouts.py".text = adaptive-layouts-source;
    })
    (mkIf (config.programs.kitty.enable && session-cfg.enable) {
      programs.kitty.actionAliases = {
        session_backup = "launch --type=background kitty-session backup";
        session_restore = "launch --type=overlay kitty-session restore";
      };
      home.file = {
        ".local/share/bash-completion/completions/kitty-session".text = kitty-session-bash-completion;
        ".zfunc/_kitty-session".text = kitty-session-zsh-completion;
        ".config/fish/completions/kitty-session.fish".text = kitty-session-fish-completion;
      };
      home.packages = [ kitty-session ];
    })
    (mkIf
      (
        config.programs.kitty.enable
        && session-cfg.enable
        && session-pi-resume-cfg.enable
        && config.programs.zsh.enable
      )
      {
        programs.zsh.envExtra = mkAfter piResumeGuard;
        programs.zsh.initContent = mkAfter piResumeDoResume;
      }
    )
    (mkIf
      (
        config.programs.kitty.enable
        && session-cfg.enable
        && session-pi-resume-cfg.enable
        && config.programs.bash.enable
      )
      {
        programs.bash.bashrcExtra = mkAfter piResumeGuard;
        programs.bash.initExtra = mkAfter piResumeDoResume;
      }
    )
    (mkIf (config.programs.kitty.enable && session-cfg.enable && config.programs.bash.enable) {
      programs.bash.initExtra = mkAfter ''
        if [[ -r "$HOME/.local/share/bash-completion/completions/kitty-session" ]]; then
          source "$HOME/.local/share/bash-completion/completions/kitty-session"
        fi
      '';
    })
  ];
}
