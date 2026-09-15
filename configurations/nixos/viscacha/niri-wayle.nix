# Host-specific niri + Wayle settings for viscacha.
#
# Only reachable through the `01-niri-wayle` specialisation, which disables KDE
# and forces PRIME sync. Everything system-level (compositor package, SDDM,
# portals, secrets, polkit, CLI tools) lives in modules/nixos/gui/niri-wayle.nix;
# this file holds the parts that depend on this machine's two monitors and on
# daily habits.
{ ... }:

let
  # region monitor facts
  #
  # eDP-1: 3200x2000 internal panel, 165 Hz, scale 2, landscape
  #        -> 1600x1000 logical
  # DP-1:  3840x2160 4K panel, scale 1.75, rotated 270, portrait
  #        -> 1234x2194 logical
  #
  # `mode` strings must match `niri msg outputs` exactly, to three decimals.
  # kscreen-doctor rounds - it reported 60.00 for DP-1 and 165.00 for eDP-1 - and
  # those values make niri warn and fall back to the *preferred* mode, which for
  # eDP-1 is 60 Hz, quietly costing the panel its 165 Hz.
  edpWidth = 1600;
  edpHeight = 1000;
  dpWidth = 1234;
  dpHeight = 2194;

  edpMode = "3200x2000@165.002";
  dpMode = "3840x2160@59.996";
  dpModeFast = "3840x2160@160.000";

  # eDP-1 is the internal panel: always on, always full speed.
  edpOn = [
    "niri msg output eDP-1 on"
    "niri msg output eDP-1 mode ${edpMode}"
    "niri msg output eDP-1 scale 2"
    "niri msg output eDP-1 transform normal"
  ];
  edpAt = x: y: [ "niri msg output eDP-1 position set ${toString x} ${toString y}" ];

  # DP-1 keeps its scale/rotation in every preset, so only mode and position vary.
  dpOn =
    mode:
    [
      "niri msg output DP-1 on"
      "niri msg output DP-1 mode ${mode}"
      "niri msg output DP-1 scale 1.75"
      "niri msg output DP-1 transform 270"
    ];
  dpAt = x: y: [ "niri msg output DP-1 position set ${toString x} ${toString y}" ];

  # Vertical offset that centres the 1000px-tall laptop panel against the 2194px
  # portrait one, matching the previous KDE arrangement.
  edpCentreY = (dpHeight - edpHeight) / 2;
in
{
  # region niri
  #
  # niri auto-positions outputs without an explicit `position` in alphabetical
  # order, and "DP-1" sorts before "eDP-1", which would put the 4K portrait panel
  # on the left. Positions are therefore always explicit.
  #
  # The per-user half is enabled here rather than from
  # modules/nixos/gui/niri-wayle.nix, so that the NixOS module stays free of Home
  # Manager wiring.
  home-manager.users.u.rabit.home.niri-wayle = {
    enable = true;

    # Boot-time arrangement. Mod+P switches between presets at runtime; note
    # that these apply immediately and are NOT written back to this file, so a
    # temporary switch only lasts until the next config reload or login.
    outputs = {
      "eDP-1" = {
        mode = edpMode;
        scale = 2.0;
        position = {
          x = 0;
          y = edpCentreY;
        };
      };
      "DP-1" = {
        mode = dpMode;
        scale = 1.75;
        transform = "270";
        position = {
          x = edpWidth;
          y = 0;
        };
      };
    };

    # Mod+P opens a fuzzel picker (KDE's Meta+P equivalent, minus mirroring -
    # niri cannot clone outputs; see modules/home/niri-wayle/default.nix).
    displayPresets = [
      {
        name = "Extend · 4K right";
        run = dpOn dpMode ++ dpAt edpWidth 0 ++ edpOn ++ edpAt 0 edpCentreY;
      }
      {
        name = "Extend · 4K left";
        run = dpOn dpMode ++ dpAt 0 0 ++ edpOn ++ edpAt dpWidth edpCentreY;
      }
      {
        name = "Extend · 4K above";
        run = dpOn dpMode ++ dpAt 0 0 ++ edpOn ++ edpAt 0 dpHeight;
      }
      {
        name = "Internal panel only";
        run = [ "niri msg output DP-1 off" ] ++ edpOn ++ edpAt 0 0;
      }
      {
        name = "4K only";
        run = [ "niri msg output eDP-1 off" ] ++ dpOn dpMode ++ dpAt 0 0;
      }
      {
        name = "4K · 160 Hz";
        run = [ "niri msg output DP-1 mode ${dpModeFast}" ];
      }
      {
        name = "4K · 60 Hz";
        run = [ "niri msg output DP-1 mode ${dpMode}" ];
      }
    ];

    # niri's stock defaults are gaps 16 and presets of 1/3, 1/2, 2/3. Tighten the
    # gaps and drop 1/2 so Mod+R cycles straight between the two widths that are
    # actually used; Mod+Ctrl+Shift+R does the same vertically inside a column.
    layout = {
      gaps = 8;
      presetColumnWidths = [
        { proportion = 0.33333; }
        { proportion = 0.66667; }
      ];
      presetWindowHeights = [
        { proportion = 0.33333; }
        { proportion = 0.66667; }
      ];
    };

    input = {
      # services.xserver.xkb.layout in configuration.nix only covers X11.
      keyboard.layout = "us";
      touchpad = {
        tap = true;
        naturalScroll = true;
        dwt = true;
      };
    };

    # Exceptions only. niri already floats windows that have a parent (dialogs)
    # and windows that are fixed size (splash screens), so most IM/messenger
    # sub-windows need nothing here. Find the app-id of a misbehaving window with
    # `niri msg pick-window`, then uncomment and fill in:
    floatingApps = [
      # "^com\\.tencent\\.wechat$"
      # "^com\\.tencent\\.dingtalk$"
    ];

    # Emitted after ./binds-default.kdl, so these win over matching stock keys.
    # Mod+P is taken by the preset picker above.
    # Note Mod+Shift+V is already taken by switch-focus-between-floating-and-tiling.
    binds = [
      ''Mod+Shift+C hotkey-overlay-title="Clipboard History: cliphist + fuzzel" { spawn-sh "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"; }''
      # Full editor, for anything the presets do not cover (arbitrary modes,
      # scaling, VRR). It applies live but cannot save: config.kdl is a read-only
      # store symlink, so copy anything you want to keep into this file.
      ''Mod+Ctrl+P hotkey-overlay-title="Display Editor: nwg-displays" { spawn "nwg-displays"; }''
    ];
  };
  # endregion niri

  # region wayle
  #
  # The rest of the shell config lives in modules/home/niri-wayle/default.nix;
  # only the host-specific bits are overridden here. Lists are replaced wholesale,
  # so re-declare a whole list when changing it - e.g. to give each monitor its
  # own bar contents:
  #
  #   bar.layout = [
  #     { monitor = "DP-1";   left = [ "dashboard" ]; center = [ "clock" ]; right = [ "niri-workspaces" "volume" ]; }
  #     { monitor = "eDP-1";  extends = "*"; right = [ "volume" "battery" ]; }
  #   ];
  home-manager.users.u.rabit.home.niri-wayle.wayle.settings = {
    # Show volume/brightness OSDs on the 4K panel rather than the laptop one.
    osd.monitor = "DP-1";

    # Wallpaper engine is off by default (Wayle would run awww). Turn it on and
    # point it at a directory to replace the KDE desktop containment:
    #
    #   wallpaper = {
    #     engine-enabled = true;
    #     cycling-directory = "/home/u/Pictures/Backgrounds";
    #     cycling-mode = "shuffle";
    #   };
  };
  # endregion wayle
}
