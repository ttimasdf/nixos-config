# NixOS module: niri + Wayle, as a replacement for a KDE Plasma session.
#
# Deliberately decoupled from Home Manager: this module owns only the
# system-level half - the compositor and its login session, the display manager,
# portals/secrets, polkit, NVIDIA quirks, and the CLI tools that niri's stock key
# bindings invoke. The per-user half (niri's config.kdl and the Wayle shell) lives
# in modules/home/niri-wayle/default.nix and is enabled independently with
# `rabit.home.niri-wayle.enable`, so a host can install the session without
# forcing anything into a user's home.
#
# See configurations/nixos/viscacha/niri-wayle.nix for a host that enables both
# halves from its 01-niri-wayle specialisation.
#
# niri needs no environment plumbing for Wayland clients: `niri --session` calls
# `systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP
# XDG_SESSION_TYPE NIRI_SOCKET` and waits for it to finish *before* sending
# READY=1 (src/main.rs import_environment()), so user services started by
# graphical-session.target already see a usable NIRI_SOCKET.
{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.rabit.nixos.gui.niri-wayle;

  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    mkDefault
    types
    optional
    ;

  niriPackage = config.programs.niri.package;
  swaylockCmd = "${pkgs.swaylock}/bin/swaylock";

  # Referenced by niri's stock key bindings
  # (modules/home/niri-wayle/binds-default.kdl):
  # Mod+D fuzzel, Super+Alt+L swaylock, XF86* brightnessctl/playerctl, Print
  # screenshot UI. The remainder replaces KDE pieces with no niri/Wayle analogue.
  tools =
    (with pkgs; [
      fuzzel # application launcher (Mod+D)
      swaylock # screen locker; niri ships none
      swayidle # idle handling, replacing PowerDevil's idle actions
      brightnessctl # XF86MonBrightness{Up,Down}
      playerctl # XF86Audio{Play,Pause,Prev,Next,Stop}
      wl-clipboard # wl-copy / wl-paste
      cliphist # clipboard history, replacing Klipper
      libnotify # notify-send, which Wayle renders as its own popup
      gammastep # night light; Wayle's hyprsunset module is Hyprland-only
      nwg-displays # monitor arrangement GUI, replacing the Display KCM
      kanshi # per-monitor-set output profiles on hotplug
      pavucontrol # audio mixer UI
      blueman # bluetooth UI
      networkmanagerapplet # nm-connection-editor
      kdePackages.polkit-kde-agent-1 # polkit authentication agent
      # Dropping KDE also drops the Breeze cursor theme that kde.nix pulled in,
      # which leaves niri logging "error loading xcursor default@48: no default
      # icon" for every cursor shape. Breeze's cursors are scalable, so they
      # cover the per-output sizes niri asks for (@48 on a 2x panel).
      kdePackages.breeze
    ])
    ++ optional cfg.enableXwaylandSatellite pkgs.xwayland-satellite;
in
{
  options.rabit.nixos.gui.niri-wayle = {
    enable = mkEnableOption "Desktop Environment: niri + Wayle";

    enableXwaylandSatellite = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install xwayland-satellite, which niri spawns on demand to run X11
        clients. niri deliberately does not integrate Xwayland itself.
      '';
    };

    enableIdle = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Run swayidle to lock the session and power off monitors when idle.
        Without this the session is never locked automatically, since niri has
        no built-in idle handling. Lid and suspend behaviour still comes from
        logind.
      '';
    };

    idle.lockAfter = mkOption {
      type = types.ints.positive;
      default = 600;
      description = "Seconds of inactivity before locking the screen.";
    };

    idle.dpmsAfter = mkOption {
      type = types.ints.positive;
      default = 900;
      description = "Seconds of inactivity before powering off monitors.";
    };

    enableNvidiaVramProfile = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install the NVIDIA application profile that stops the GL heap from
        growing inside Wayland compositors (`GLVidHeapReuseRatio = 0` for the
        niri process). Only applied when {option}`hardware.nvidia` is enabled.
      '';
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra system packages for the niri session.";
    };
  };

  config = mkIf cfg.enable {
    programs.niri.enable = true;

    # modules/nixos/gui/kde.nix is what normally provides SDDM. The
    # 01-niri-wayle specialisation disables KDE, so this module has to own the
    # display manager or there would be no way to log in.
    services.displayManager.sddm.enable = mkDefault true;
    # SDDM's X11 greeter. The Wayland greeter is left off: the plasma6 module
    # can only use it because it reuses kwin.
    services.xserver.enable = mkDefault true;

    environment.systemPackages = tools ++ cfg.extraPackages;

    # services.desktopManager.plasma6 enables these with mkDefault. When KDE is
    # disabled in a specialisation they would silently disappear, taking audio,
    # touchpad support, automounting, battery reporting, firmware updates and
    # dconf with them. Restated here with mkDefault so an explicit host setting
    # still wins.
    programs.dconf.enable = mkDefault true;
    programs.fuse.enable = mkDefault true;
    services.udisks2.enable = mkDefault true;
    services.upower.enable = mkDefault true;
    services.libinput.enable = mkDefault true;
    services.pipewire.enable = mkDefault true;
    services.geoclue2.enable = mkDefault true;
    services.fwupd.enable = mkDefault true;
    services.orca.enable = mkDefault true;

    # gnome-keyring is niri's upstream recommendation and supplies the Secret
    # portal; the nixpkgs niri module already enables it with mkDefault. Its own
    # module only wires up the `login` PAM service, so add the one SDDM uses, or
    # the keyring stays locked and prompts on first use.
    security.pam.services.sddm.enableGnomeKeyring = config.services.gnome.gnome-keyring.enable;

    # gcr-ssh-agent defaults its `enable` to services.gnome.gnome-keyring.enable,
    # and asserts against programs.ssh.startAgent, because only one SSH agent can
    # be installed at a time. The host uses programs.ssh.startAgent, so keep the
    # keyring's Secret service but drop gcr's SSH agent. Left alone when
    # startAgent is off, where gcr's agent is the better default.
    services.gnome.gcr-ssh-agent.enable = mkIf config.programs.ssh.startAgent false;

    # niri recommends plasma-polkit-agent. The package ships a unit but nothing
    # starts it outside Plasma, and it has no WantedBy.
    systemd.user.services.plasma-polkit-agent = {
      description = "KDE PolicyKit Authentication Agent";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        BusName = "org.kde.polkit-kde-authentication-agent-1";
        Slice = "background.slice";
        TimeoutStopSec = 5;
        Restart = "on-failure";
      };
    };

    # Replaces PowerDevil's idle actions. `-w` makes swayidle wait for each
    # command to exit, so the locker is up before the monitors go off.
    systemd.user.services.swayidle = mkIf cfg.enableIdle {
      description = "Idle management for the niri session";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.swayidle}/bin/swayidle -w "
          + "timeout ${toString cfg.idle.lockAfter} '${swaylockCmd} -f' "
          + "timeout ${toString cfg.idle.dpmsAfter} '${niriPackage}/bin/niri msg action power-off-monitors' "
          + "before-sleep '${swaylockCmd} -f' "
          + "after-resume '${niriPackage}/bin/niri msg action power-on-monitors'";
        Restart = "on-failure";
      };
    };

    # Keeps VRAM at ~100MiB instead of ~1GiB by disabling the driver's free
    # buffer pool for niri. See niri's wiki page "Nvidia".
    environment.etc = mkIf (cfg.enableNvidiaVramProfile && (config.hardware.nvidia.enabled or false)) {
      "nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
        builtins.toJSON {
          rules = [
            {
              pattern = {
                feature = "procname";
                matches = "niri";
              };
              profile = "Limit Free Buffer Pool On Wayland Compositors";
            }
          ];
          profiles = [
            {
              name = "Limit Free Buffer Pool On Wayland Compositors";
              settings = [
                {
                  key = "GLVidHeapReuseRatio";
                  value = 0;
                }
              ];
            }
          ];
        };
    };

    # Electron only defaults to Wayland from v39 onwards; older versions need
    # this hint. Deliberately not touching GDK_BACKEND, which breaks the
    # screencast portal.
    environment.sessionVariables.ELECTRON_OZONE_PLATFORM_HINT = "auto";

    # Point the whole session at the cursor theme installed above. niri reads
    # this for its own cursor and passes it on to clients; without it, clients
    # fall back to a missing "default" theme.
    environment.sessionVariables.XCURSOR_THEME = "breeze_cursors";
  };
}
