{ config, lib, pkgs, isDarwin, ... }:
let
  inherit (lib) mkIf mkMerge mkOption mkAfter types optional assertMsg;
  cfg = config.rabit.home.kitty.kitty-in-tab;

  flake8IgnoredErrors = [
    "E111"  # indentation is not a multiple of 4
    "E114"  # indentation is not a multiple of 4 (comment)
    "E121"  # continuation line under-indented for hanging indent
    "E501"  # line too long
  ];

  kitty-is-cmd-allowed-source = ''
    import logging
    import subprocess
    import sys

    log = logging.getLogger("kitty-is-cmd-allowed")
    log.setLevel(logging.${if cfg.debug_log.enable then "DEBUG" else "INFO"})
    log.addHandler(logging.StreamHandler())

    def notify(title, message, urgency="normal"):
      """Send desktop notification."""
      try:
        subprocess.run(["${lib.getExe pkgs.libnotify}", "-a", "kitty-is-cmd-allowed", "-i", "kitty", "-u", urgency, title, message], check=False)
      except Exception:
        pass


    def is_cmd_allowed(pcmd, window, from_socket, extra_data):
        cmd_name = pcmd['cmd']  # the name of the command
        cmd_payload = pcmd['payload']  # the arguments to the command
        # examine the cmd_name and cmd_payload and return True to allow
        # the command or False to disallow it. Return None to have no
        # effect on the command.

        log.debug('is_cmd_allowed called: cmd_name=%s, cmd_payload=%s, window=%s, from_socket=%s', cmd_name, cmd_payload, window, from_socket)

        if cmd_name in {"focus-tab", "focus-window", "select-window"}:
            log.info('Command whitelist: %s', cmd_name)
            return True
        elif cmd_name not in {"launch"}:
            log.debug('Allowing non-launch command: %s', cmd_name)
            return None
        if cmd_payload.get('args') or cmd_payload.get('env') or cmd_payload.get('copy_cmdline') or cmd_payload.get('copy_env'):
            log.warning('Blocking launch command with restricted args: %s', cmd_payload)
            notify('Blocking launch command', f"restricted args: {cmd_payload}")
            return False
        # prints in this function go to the parent kitty process STDOUT
        log.info('Allowing launch command: %s', cmd_payload)
        return True


    if __name__ == "__main__":
      # Read JSON input from stdin for testing
      import json
      data = json.load(sys.stdin)
      result = is_cmd_allowed(data.get('pcmd', {}), data.get('window'), data.get('from_socket'), data.get('extra_data'))
      print(result)
  '';

  kitty-in-tab =
    let
      name = "kitty-in-tab";
      script = pkgs.writers.writePython3Bin name {
        libraries = with pkgs.python3Packages; [ systemd-python ];
        flakeIgnore = flake8IgnoredErrors;
        makeWrapperArgs = [
          "--prefix" "PATH" ":" "${lib.makeBinPath [ pkgs.libnotify ]}"
        ];
      } ''
        import logging
        import os
        import subprocess
        import sys
        from pathlib import Path


        log = logging.getLogger("${name}")
        log.setLevel(logging.${if cfg.debug_log.enable then "DEBUG" else "INFO"})
        log.addHandler(logging.StreamHandler())

        try:
          # Optional, if needed, add `libraries = with pkgs.python3Packages; [ systemd-python ];`
          # to writePython3Bin arguments
          from systemd.journal import JournalHandler

          log.addHandler(JournalHandler(SYSLOG_IDENTIFIER="${name}"))
        except ImportError:
          pass

        if not (runtime_dir := os.getenv("XDG_RUNTIME_DIR")):
          raise RuntimeError("XDG_RUNTIME_DIR is not set")

        RUNTIME_DIR = Path(runtime_dir)
        SOCK_PREFIX = "kitty-rc"
        PASSWORD = ""


        def find_sock():
          """Find the most recent kitty-rc-{pid} socket."""
          socks = sorted(
            RUNTIME_DIR.glob(SOCK_PREFIX + "-*"),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
          )
          if socks:
            log.debug("found sockets: %s", socks)
            return "unix:" + str(socks[0])
          log.debug("no existing kitty sockets found")
          return None


        def parse_args(argv):
          title = None
          app_id = None
          cwd = os.getcwd()
          hold = False
          cmd = []
          it = iter(argv[1:])
          for arg in it:
            if arg == "--":
              cmd = list(it)
              break
            elif arg == "--title":
              title = next(it, None)
            elif arg == "--class":
              app_id = next(it, None)
            elif arg == "--working-directory":
              cwd = next(it, None)
            elif arg == "--hold":
              hold = True
          return title, app_id, cwd, hold, cmd


        def notify(title, message, urgency="normal"):
          """Send desktop notification."""
          try:
            subprocess.run(["notify-send", "-a", "${name}", "-i", "kitty", "-u", urgency, title, message], check=False)
          except Exception:
            pass


        def try_remote_launch(sock, title, cwd, hold, cmd):
          remote_base = ["kitten", "@", "--to", sock]
          if PASSWORD and not os.getenv("KITTY_PUBLIC_KEY"):
            # remote_base += ["--password", PASSWORD]
            log.critical("password protected remote launch outside of kitty is unsupported")
            notify("Remote launch error", "password protected remote launch outside of kitty is unsupported", urgency="critical")
            return False
          launch_args = remote_base + ["launch", "--type=tab"]
          if title:
            launch_args += ["--tab-title", title]
          if cwd:
            launch_args += ["--cwd", cwd]
          if hold:
            launch_args.append("--hold")
          launch_args += cmd
          log.info("remote launch: %s", launch_args)
          result = subprocess.run(launch_args, capture_output=True, text=True)
          if result.returncode == 0:
            window_id = result.stdout.strip()
            log.info("tab launched, focusing window %s", window_id)
            subprocess.run(remote_base + ["focus-window", "-m", f"id:{window_id}"])
            return True
          log.warning("remote launch failed (rc=%d): %s", result.returncode, result.stderr.strip())
          notify("Remote launch failed", result.stderr.strip())
          return False


        def fallback_launch(title, app_id, cwd, hold, cmd):
          args = ["kitty"]
          if title:
            args += ["--title", title]
          if app_id:
            args += ["--class", app_id]
          if cwd:
            args += ["--directory", cwd]
          if hold:
            args.append("--hold")
          if cmd:
            args.append("--")
            args += cmd
          log.info("fallback: exec %s", args)
          os.execvp("kitty", args)


        def main():
          log.debug("argv: %s", sys.argv)
          title, app_id, cwd, hold, cmd = parse_args(sys.argv)
          log.info(
            "parsed: title=%s app_id=%s cwd=%s hold=%s cmd=%s",
            title, app_id, cwd, hold, cmd,
          )
          sock = find_sock()
          if sock and try_remote_launch(sock, title, cwd, hold, cmd):
            return
          fallback_launch(title, app_id, cwd, hold, cmd)


        if __name__ == "__main__":
          main()
      '';
      desktopItem = pkgs.makeDesktopItem {
        inherit name;
        desktopName = "Kitty New Tab Handler";
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
  options.rabit.home.kitty.kitty-in-tab = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable kitty-in-tab, a script that opens new tabs in an existing Kitty window
        instead of launching a new Kitty instance.
      '';
    };

    debug_log = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable debug logging for kitty-in-tab and kitty-is-cmd-allowed scripts.
        '';
      };
    };
  };

  config = mkMerge [
    {
      assertions = [
        {
          assertion = cfg.enable -> config.programs.kitty.enable;
          message = "rabit.home.kitty.kitty-in-tab.enable requires programs.kitty.enable to be true";
        }
      ];
    }
    (mkIf (config.programs.kitty.enable && cfg.enable) {
    programs.kitty.settings = {
      listen_on = "unix:\${XDG_RUNTIME_DIR}/kitty-rc";
      allow_remote_control = "password";
    };
    programs.kitty.extraConfig = mkAfter ''
      remote_control_password "" is_cmd_allowed.py
    '';
    xdg.configFile."kitty/is_cmd_allowed.py".text = kitty-is-cmd-allowed-source;
    home.packages = [ kitty-in-tab ];
    })
  ];
}