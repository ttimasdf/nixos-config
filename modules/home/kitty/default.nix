{ config, lib, pkgs, isDarwin, ... }:
let
  inherit (lib) mkIf mkMerge mkOption mkAfter types optional assertMsg;
  cfg = config.rabit.home.kitty.kitty-new-tab;

  flake8IgnoredErrors = [
    "E111" # indentation is not a multiple of 4
    "E114" # indentation is not a multiple of 4 (comment)
    "E121" # continuation line under-indented for hanging indent
    "E501" # line too long
  ];

  kitty-is-cmd-allowed-source = builtins.replaceStrings
    [ "@libnotify@" "@log_level@" ]
    [
      (lib.getExe pkgs.libnotify)
      (if cfg.debug_log.enable then "DEBUG" else "INFO")
    ]
    (builtins.readFile ./kitty_is_cmd_allowed.py);

  kitty-new-tab =
    let
      name = "kitty-new-tab";
      script = pkgs.writers.writePython3Bin name
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
        (builtins.replaceStrings
          [ "@name@" "@log_level@" ]
          [
            name
            (if cfg.debug_log.enable then "DEBUG" else "INFO")
          ]
          (builtins.readFile ./kitty_new_tab.py));
      desktopItem = pkgs.makeDesktopItem {
        inherit name;
        desktopName = "Kitty New-Tab Handler";
        genericName = "Terminal emulator";
        comment = "Open a new tab in Kitty";
        icon = "kitty";
        startupWMClass = "kitty";
        exec = "${script}/bin/${name}";
        tryExec = name;
        categories = [ "System" "TerminalEmulator" ];
        startupNotify = true;
        extraConfig = {
          X-TerminalArgExec = "--";
          X-TerminalArgTitle = "--title";
          X-TerminalArgAppId = "--class";
          X-TerminalArgDir = "--working-directory";
          X-TerminalArgHold = "--hold";
        };
        noDisplay = true;
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

  config = mkMerge [
    {
      assertions = [
        {
          assertion = cfg.enable -> config.programs.kitty.enable;
          message = "rabit.home.kitty.kitty-new-tab.enable requires programs.kitty.enable to be true";
        }
      ];
    }
    (mkIf (config.programs.kitty.enable && cfg.enable) {
      programs.kitty.settings = {
        listen_on = "unix:\${XDG_RUNTIME_DIR}/kitty-rc";
        allow_remote_control = "password";
      };
      programs.kitty.extraConfig = mkAfter ''
        remote_control_password "" kitty_is_cmd_allowed.py
      '';
      xdg.configFile."kitty/kitty_is_cmd_allowed.py".text = kitty-is-cmd-allowed-source;
      home.packages = [ kitty-new-tab ];
    })
  ];
}
