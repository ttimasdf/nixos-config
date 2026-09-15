# Home Manager module: the niri + Wayle desktop.
#
# These two always ship together - niri is the compositor, Wayle is the shell that
# replaces what plasmashell used to provide - so they share a single option
# namespace, `rabit.home.niri-wayle`. Everything niri-specific sits at the top
# level of that namespace; everything Wayle-specific is under `.wayle`.
#
# Generates ~/.config/niri/config.kdl from Nix options. Because that file ends
# up as a read-only store symlink, two escape hatches exist so ordinary
# day-to-day changes never require a rebuild:
#
#   * `rabit.home.niri-wayle.localConfig` appends `include optional=true "local.kdl"`,
#     so a hand-written ~/.config/niri/local.kdl overrides anything generated
#     here (niri includes are positional and merge by key).
#   * Runtime IPC keeps working regardless: `niri msg output ...`,
#     `niri msg action ...`, plus `nwg-displays` for monitor arrangement.
#
# References: https://yalter.github.io/niri/Configuration:-Introduction.html
#             https://wayle.app/config/
{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.rabit.home.niri-wayle;

  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  # ---------------------------------------------------------------------------
  # KDL emitters
  # ---------------------------------------------------------------------------
  pad = n: lib.concatStrings (lib.replicate n "    ");

  # Indent every line of a possibly multi-line fragment.
  indentLines =
    n: s:
    let
      lines = lib.splitString "\n" (lib.removeSuffix "\n" s);
    in
    lib.concatMapStringsSep "\n" (l: if l == "" then "" else pad n + l) lines;

  # Emit `name { ... }`, or nothing when every line is absent. Sections are only
  # written when they carry content so the generated file stays readable and we
  # never accidentally emit an "enabled" empty section (niri treats a bare
  # `border {}` in the main config as "turn the border on").
  block =
    level: name: lines:
    let
      kept = builtins.filter (l: l != null && l != "") lines;
    in
    lib.optionalString (kept != [ ]) (
      "${pad level}${name} {\n"
      + indentLines (level + 1) (lib.concatMapStringsSep "\n" (l: l) kept)
      + "\n${pad level}}\n"
    );

  # KDL string literal. Escape backslashes before quotes.
  str = s: "\"${lib.escape [ "\\" "\"" ] (toString s)}\"";

  # Nix formats floats with a fixed six decimals, so 0.33333 would be written as
  # "0.333330" and a scale of 2.0 as "2.000000". niri accepts those, but trim the
  # noise while always keeping a decimal point so the value stays a KDL float.
  num =
    x:
    if !builtins.isFloat x then
      toString x
    else
      let
        rendered = builtins.toString x;
        # Strip trailing zeros: "0.333330" -> "0.33333", "2.000000" -> "2.".
        stripped = builtins.match "(.*[^0])0+$" rendered;
        trimmed = if stripped == null then rendered else builtins.head stripped;
      in
      if lib.hasSuffix "." trimmed then
        lib.removeSuffix "." trimmed + ".0"
      else
        trimmed;

  # ---------------------------------------------------------------------------
  # Reusable option types
  # ---------------------------------------------------------------------------
  sizeType = types.submodule {
    options = {
      proportion = mkOption {
        type = types.nullOr types.float;
        default = null;
        description = "Fraction of the output, gaps included. Mutually exclusive with fixed.";
      };
      fixed = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = "Exact width/height in logical pixels. Mutually exclusive with proportion.";
      };
    };
  };

  sizeLine =
    s:
    if s.proportion != null then
      "proportion ${num s.proportion}"
    else if s.fixed != null then
      "fixed ${toString s.fixed}"
    else
      throw "rabit.home.niri-wayle: size entries need either `proportion` or `fixed`";

  # ---------------------------------------------------------------------------
  # outputs
  # ---------------------------------------------------------------------------
  outputBody =
    o:
    [
      (lib.optionalString o.off "off")
      (lib.optionalString (o.mode != null) "mode ${str o.mode}")
      (lib.optionalString (o.scale != null) "scale ${num o.scale}")
      (lib.optionalString (o.transform != null) "transform ${str o.transform}")
      (lib.optionalString
        (
          o.position != null
        ) "position x=${toString o.position.x} y=${toString o.position.y}")
      (lib.optionalString o.variableRefreshRate (
        "variable-refresh-rate" + lib.optionalString o.variableRefreshRateOnDemand " on-demand=true"
      ))
      (lib.optionalString o.focusAtStartup "focus-at-startup")
      (lib.optionalString (o.backgroundColor != null) "background-color ${str o.backgroundColor}")
      (lib.optionalString (o.backdropColor != null) "backdrop-color ${str o.backdropColor}")
      (lib.optionalString (o.extra != null) o.extra)
    ];

  # niri sorts unnamed outputs by name when auto-positioning, and "DP-1" sorts
  # before "eDP-1" - so an explicit position is required whenever the physical
  # arrangement differs from that name order.
  outputSections = lib.concatStrings (
    lib.mapAttrsToList (name: o: block 0 "output ${str name}" (outputBody o)) cfg.outputs
  );

  # ---------------------------------------------------------------------------
  # layout / input
  # ---------------------------------------------------------------------------
  layoutSection = block 0 "layout" [
    (lib.optionalString (cfg.layout.gaps != null) "gaps ${toString cfg.layout.gaps}")
    (lib.optionalString
      (
        cfg.layout.centerFocusedColumn != null
      ) "center-focused-column ${str cfg.layout.centerFocusedColumn}")
    (lib.optionalString (cfg.layout.defaultColumnWidth != null) (
      block 0 "default-column-width" [ (sizeLine cfg.layout.defaultColumnWidth) ]
    ))
    (lib.optionalString (cfg.layout.presetColumnWidths != [ ]) (
      block 0 "preset-column-widths" (map sizeLine cfg.layout.presetColumnWidths)
    ))
    (lib.optionalString (cfg.layout.presetWindowHeights != [ ]) (
      block 0 "preset-window-heights" (map sizeLine cfg.layout.presetWindowHeights)
    ))
    (lib.optionalString (cfg.layout.struts != null) (
      block 0 "struts" (
        lib.mapAttrsToList (k: v: "${k} ${toString v}") (
          lib.filterAttrs (_: v: v != null) cfg.layout.struts
        )
      )
    ))
    cfg.layout.extra
  ];

  inputSection = block 0 "input" [
    (lib.optionalString
      (
        cfg.input.keyboard.layout != null
        || cfg.input.keyboard.variant != null
        || cfg.input.keyboard.options != null
        || cfg.input.keyboard.numlock
      )
      (block 0 "keyboard" [
        (block 0 "xkb" [
          (lib.optionalString
            (
              cfg.input.keyboard.layout != null
            ) "layout ${str cfg.input.keyboard.layout}")
          (lib.optionalString
            (
              cfg.input.keyboard.variant != null
            ) "variant ${str cfg.input.keyboard.variant}")
          (lib.optionalString
            (
              cfg.input.keyboard.options != null
            ) "options ${str cfg.input.keyboard.options}")
        ])
        (lib.optionalString cfg.input.keyboard.numlock "numlock")
      ]))
    (lib.optionalString (cfg.input.touchpad != null) (
      block 0 "touchpad" (
        [
          (lib.optionalString cfg.input.touchpad.tap "tap")
          (lib.optionalString cfg.input.touchpad.dwt "dwt")
          (lib.optionalString cfg.input.touchpad.dwtp "dwtp")
          (lib.optionalString cfg.input.touchpad.drag "drag")
          (lib.optionalString cfg.input.touchpad.dragLock "drag-lock")
          (lib.optionalString cfg.input.touchpad.naturalScroll "natural-scroll")
          (lib.optionalString
            (
              cfg.input.touchpad.accelSpeed != null
            ) "accel-speed ${num cfg.input.touchpad.accelSpeed}")
          (lib.optionalString
            (
              cfg.input.touchpad.accelProfile != null
            ) "accel-profile ${str cfg.input.touchpad.accelProfile}")
          (lib.optionalString
            (
              cfg.input.touchpad.disabledOnExternalMouse
            ) "disabled-on-external-mouse")
        ]
        ++ cfg.input.touchpad.extra
      )
    ))
    (lib.optionalString (cfg.input.mouse != null) (
      block 0 "mouse" (
        [
          (lib.optionalString cfg.input.mouse.naturalScroll "natural-scroll")
          (lib.optionalString
            (
              cfg.input.mouse.accelSpeed != null
            ) "accel-speed ${num cfg.input.mouse.accelSpeed}")
          (lib.optionalString
            (
              cfg.input.mouse.accelProfile != null
            ) "accel-profile ${str cfg.input.mouse.accelProfile}")
        ]
        ++ cfg.input.mouse.extra
      )
    ))
    (lib.optionalString cfg.input.warpMouseToFocus "warp-mouse-to-focus")
    (lib.optionalString
      (
        cfg.input.focusFollowsMouse != null
      ) "focus-follows-mouse max-scroll-amount=${str cfg.input.focusFollowsMouse}")
    cfg.input.extra
  ];

  # ---------------------------------------------------------------------------
  # window rules
  # ---------------------------------------------------------------------------
  floatingRules = map
    (appId: ''
      window-rule {
          match app-id=${str appId}
          open-floating true
      }
    '')
    cfg.floatingApps;

  blockOutRules = map
    (appId: ''
      window-rule {
          match app-id=${str appId}
          block-out-from "screencast"
      }
    '')
    cfg.blockOutFromScreencast;

  castTargetRule = lib.optionalString cfg.highlightCastTarget ''
    window-rule {
        match is-window-cast-target=true

        focus-ring {
            active-color "#f38ba8"
            inactive-color "#7d0d2d"
        }

        border {
            inactive-color "#7d0d2d"
        }
    }
  '';

  ruleSections =
    lib.concatStrings floatingRules
    + lib.concatStrings blockOutRules
    + castTargetRule
    + lib.concatStrings (map (r: "${r}\n") cfg.windowRules);

  # ---------------------------------------------------------------------------
  # startup + binds
  # ---------------------------------------------------------------------------
  spawnSection = lib.concatMapStringsSep "\n"
    (
      c: "spawn-at-startup ${str c}"
    )
    cfg.spawnAtStartup
  + lib.optionalString (cfg.spawnAtStartup != [ ]) "\n";

  bindsSection = block 0 "binds" ([
    # Overrides for the stock bindings. niri merges `binds` by key and later
    # definitions win, so anything set here beats ./binds-default.kdl.
    "Mod+T hotkey-overlay-title=\"Open a Terminal: ${cfg.terminal}\" { spawn ${str cfg.terminal}; }"
    "Mod+D hotkey-overlay-title=\"Run an Application: ${cfg.launcher}\" { spawn ${str cfg.launcher}; }"
    "Super+Alt+L allow-when-locked=true hotkey-overlay-title=null { spawn-sh ${str cfg.lockCommand}; }"
  ] ++ presetBinds ++ cfg.binds);

  # ---------------------------------------------------------------------------
  # display presets
  # ---------------------------------------------------------------------------
  # niri cannot mirror outputs - its own wiki's "Screen mirroring" section points
  # at wl-mirror, which mirrors an output into a *window* you then fullscreen. So
  # presets cover what `niri msg output` can actually do: arrangement, enable and
  # disable, and mode/refresh switching.
  presetTable = lib.concatMapStringsSep "\n"
    (
      p: "${p.name}\t${lib.concatStringsSep " ; " p.run}"
    )
    allPresets;

  # Kept as its own file rather than a shell literal: preset command lines are
  # fragments meant to expand later ($INTERNAL/$EXTERNAL), which shellcheck would
  # flag as SC2016, and preset names may contain non-ASCII characters that
  # shellcheck cannot always render in a non-UTF-8 build sandbox.
  presetTableFile = pkgs.writeText "niri-display-presets.tsv" presetTable;

  presetScript = pkgs.writeShellApplication {
    name = "niri-display-preset";
    runtimeInputs = with pkgs; [
      niri
      fuzzel
      libnotify
      jq
      procps # pkill, used to drop a stray wl-mirror
    ];
    text = ''
      # Generated by rabit.home.niri-wayle. Edit `displayPresets` in Nix, not
      # this file. The preset table is a TSV of `name<TAB>command ; command`,
      # read at runtime; the commands are shell fragments expanded when applied.
      table=$(cat ${presetTableFile})

      notify() {
        notify-send --app-name=Display --icon=video-display \
          --expire-time=2500 "$1" "$2" 2>/dev/null || true
      }

      # Presets refer to $INTERNAL / $EXTERNAL rather than connector names, so they
      # survive DP-1 -> DP-2 renumbering when a dock, port or monitor changes.
      # The internal panel is the eDP-* output; the external is the first other.
      resolve_roles() {
        local json
        json=$(niri msg --json outputs 2>/dev/null) || return 0
        INTERNAL=$(printf '%s' "$json" | jq -r '[keys[] | select(startswith("eDP"))][0] // empty')
        EXTERNAL=$(printf '%s' "$json" | jq -r --arg i "$INTERNAL" '[keys[] | select(. != $i)][0] // empty')
        export INTERNAL EXTERNAL
      }

      # niri cannot clone outputs, so mirroring is wl-mirror drawing the source
      # output fullscreen onto the target. It runs as a transient user unit, so it
      # outlives this script, shows up in `systemctl --user status wl-mirror`, and
      # stops cleanly. Any preset change first drops an active mirror.
      stop_mirror() {
        systemctl --user stop wl-mirror.service >/dev/null 2>&1 || true
        pkill -x wl-mirror >/dev/null 2>&1 || true
      }

      names() {
        while IFS=$'\t' read -r name _; do
          [ -n "$name" ] && printf '%s\n' "$name"
        done <<<"$table"
      }

      commands_for() {
        local want=$1 name cmds
        while IFS=$'\t' read -r name cmds; do
          if [ "$name" = "$want" ]; then
            printf '%s' "$cmds"
            return 0
          fi
        done <<<"$table"
        return 1
      }

      apply_preset() {
        local name=$1 cmds line
        local -a failed=()
        cmds=$(commands_for "$name") || {
          echo "unknown preset: $name" >&2
          exit 2
        }
        # A preset supersedes whatever layout is active, including a mirror.
        stop_mirror
        resolve_roles
        while IFS= read -r line; do
          # trim surrounding whitespace
          line="''${line#"''${line%%[![:space:]]*}"}"
          line="''${line%"''${line##*[![:space:]]}"}"
          [ -n "$line" ] || continue
          # Presets are plain command lines; run each through sh so quoting and
          # chaining work exactly as they would in a key binding.
          if ! sh -c "$line" >/dev/null 2>&1; then
            failed+=("$line")
          fi
        done < <(printf '%s' "$cmds" | tr ';' '\n')
        if [ ''${#failed[@]} -gt 0 ]; then
          notify "$name (failed)" "$(printf '%s; ' "''${failed[@]}")"
          exit 1
        fi
        # Summary is the preset name, body is the resulting state, so the
        # notification reads like KDE's display-configuration OSD.
        notify "$name" "$(status)"
      }

      # Compact summary of what is currently on, for a bar module:
      #   eDP-1 165Hz + DP-1 60Hz
      # niri reports refresh_rate in millihertz, hence the /1000.
      status() {
        niri msg --json outputs | jq -r '
          [ to_entries[]
            | select(.value.current_mode != null)
            | "\(.key) \(.value.modes[.value.current_mode].refresh_rate / 1000 | round)Hz"
          ] | if length == 0 then "no outputs" else join(" + ") end'
      }

      case "''${1:-menu}" in
        menu)
          selection=$(names | fuzzel --dmenu --prompt="Display: " --width=38 --lines=10) || exit 0
          [ -n "$selection" ] || exit 0
          apply_preset "$selection"
          ;;
        list) names ;;
        status) status ;;
        stop-mirror) stop_mirror ;;
        roles)
          resolve_roles
          echo "INTERNAL=''${INTERNAL-} EXTERNAL=''${EXTERNAL-}"
          ;;
        apply)
          shift
          [ "$#" -gt 0 ] || {
            echo "usage: niri-display-preset apply <name>" >&2
            exit 2
          }
          apply_preset "$*"
          ;;
        help | -h | --help)
          cat <<'USAGE'
      usage: niri-display-preset [menu|list|status|roles|stop-mirror|apply <name>]

        menu         pick a preset interactively (default, bound to Mod+P)
        list         print preset names
        status       print the currently active outputs and refresh rates
        roles        print the resolved $INTERNAL / $EXTERNAL output names
        stop-mirror  stop a wl-mirror started by a mirror preset
        apply        apply one preset by its exact name

      Inside a preset command line, $INTERNAL and $EXTERNAL name the internal
      panel and the external display, so presets keep working when connectors are
      renumbered.
      USAGE
          ;;
        *)
          echo "unknown command: $1 (try --help)" >&2
          exit 2
          ;;
      esac
    '';
  };

  # Mirroring is not something niri can do itself: wl-mirror draws the source
  # output fullscreen on the target. These presets are role-based, so they work on
  # any machine with an internal panel plus an external display.
  #
  # The command lines are self-contained - absolute wl-mirror path, no helper
  # script self-reference, which would make the script's store path depend on its
  # own content. `apply_preset` stops an existing mirror before running them.
  mirrorPresetsList =
    let
      startMirror =
        source: target:
        ''systemd-run --user --unit=wl-mirror --collect --description="wl-mirror: ${source} on ${target}" "${pkgs.wl-mirror}/bin/wl-mirror" --fullscreen-output "${target}" "${source}"'';
    in
    lib.optionals (cfg.mirrorPresets && cfg.displayPresets != [ ]) [
      {
        name = "Mirror · external onto internal";
        run = [ (startMirror "$EXTERNAL" "$INTERNAL") ];
      }
      {
        name = "Mirror · internal onto external";
        run = [ (startMirror "$INTERNAL" "$EXTERNAL") ];
      }
      {
        # apply_preset drops the mirror before running anything, so this entry
        # only has to leave the arrangement alone.
        name = "Stop mirroring";
        run = [ ];
      }
    ];

  allPresets = cfg.displayPresets ++ mirrorPresetsList;

  # Only wire these up when presets are configured; the arrangement list is
  # hardware-specific so this module ships none by default.
  hasDisplayPresets = allPresets != [ ];

  presetBinds = lib.optionals hasDisplayPresets [
    ''${cfg.displayPresetKey} repeat=false hotkey-overlay-title="Display Presets: ${presetScript.name}" { spawn-sh ${str "${presetScript}/bin/niri-display-preset menu"}; }''
  ];

  # ---------------------------------------------------------------------------
  # whole file
  # ---------------------------------------------------------------------------
  stockBindsInclude = lib.optionalString cfg.stockBinds ''
    // Upstream niri key bindings. Bind overrides below win by position.
    include ${str "${./binds-default.kdl}"}
  '';

  localInclude = lib.optionalString cfg.localConfig ''
    // Hand-written overrides, applied last so they win over everything above.
    include optional=true "local.kdl"
  '';

  # ---------------------------------------------------------------------------
  # Wayle
  # ---------------------------------------------------------------------------
  # Minimal, documented-valid starting point. Deliberately small: an invalid key
  # here would break Wayle's TOML parse on first boot, so anything not modelled
  # by `wayle.settings` falls back to Wayle's own defaults.
  defaultWayleSettings = {
    bar = {
      location = "top";
      scale = 1;
      layout = [
        {
          monitor = "*";
          show = true;
          left = [ "dashboard" ];
          center = [ "clock" ];
          right = [
            "niri-workspaces"
          ] ++ lib.optional hasDisplayPresets "custom-display" ++ [
            "systray"
            "volume"
            "network"
            "bluetooth"
            "battery"
          ];
        }
      ];
    };
    modules.clock.format = "%H:%M";

    # Clickable display indicator: shows the active outputs in its tooltip and
    # opens the preset picker on left click, so switching layouts does not need
    # the Mod+P chord either.
    modules.custom = lib.optional hasDisplayPresets {
      id = "display";
      command = "${presetScript}/bin/niri-display-preset status";
      interval-ms = 5000;
      icon-name = "ld-monitor-symbolic";
      icon-show = true;
      label-show = false;
      tooltip-format = "{{ output }}";
      left-click = "${presetScript}/bin/niri-display-preset menu";
      right-click = "nwg-displays";
    };
  };

  generated = ''
    // Generated by rabit.home.niri-wayle - do not edit, edit the Nix options instead.
    // Hand edits belong in ~/.config/niri/local.kdl (included at the end).

    ${stockBindsInclude}
    ${inputSection}${layoutSection}${outputSections}${ruleSections}${spawnSection}${bindsSection}
    ${cfg.extraConfig}
    ${localInclude}
  '';
in
{
  options.rabit.home.niri-wayle = {
    enable = mkEnableOption "niri configuration managed by Home Manager";

    stockBinds = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Include niri's upstream default key bindings (shipped verbatim in
        ./binds-default.kdl). Only disable this if you intend to bind every
        action yourself.
      '';
    };

    localConfig = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Append `include optional=true "local.kdl"` so that a hand-written
        ~/.config/niri/local.kdl can override anything generated here without a
        rebuild.
      '';
    };

    terminal = mkOption {
      type = types.str;
      default = "kitty";
      description = "Terminal spawned by the Mod+T binding.";
    };

    launcher = mkOption {
      type = types.str;
      default = "fuzzel";
      description = "Application launcher spawned by the Mod+D binding.";
    };

    lockCommand = mkOption {
      type = types.str;
      default = "swaylock -f";
      example = "swaylock -f -c 000000";
      description = "Command run by the Super+Alt+L binding.";
    };

    outputs = mkOption {
      default = { };
      description = ''
        Per-output settings, keyed by connector name (e.g. "eDP-1", "DP-1") or
        by "<make> <model> <serial>" as reported by `niri msg outputs`.

        Outputs not listed here are still enabled automatically at their
        preferred mode, with a scale guessed from physical dimensions, and
        positioned to avoid overlap - so a brand-new monitor needs no config.
        Set `position` explicitly when the desired arrangement does not match
        niri's alphabetical auto-positioning.
      '';
      type = types.attrsOf (
        types.submodule {
          options = {
            off = mkOption {
              type = types.bool;
              default = false;
              description = "Turn this output off entirely.";
            };
            mode = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "3840x2160@60.000";
              description = "Mode string; must match `niri msg outputs` exactly, to three decimals.";
            };
            scale = mkOption {
              type = types.nullOr types.float;
              default = null;
              example = 1.75;
              description = "Fractional scale. Unset lets niri guess from the physical size.";
            };
            transform = mkOption {
              type = types.nullOr (
                types.enum [
                  "normal"
                  "90"
                  "180"
                  "270"
                  "flipped"
                  "flipped-90"
                  "flipped-180"
                  "flipped-270"
                ]
              );
              default = null;
              description = "Rotation, counter-clockwise. Use \"270\" or \"90\" for a portrait panel.";
            };
            position = mkOption {
              type = types.nullOr (
                types.submodule {
                  options = {
                    x = mkOption {
                      type = types.int;
                      description = "Logical X, i.e. scaled pixels.";
                    };
                    y = mkOption {
                      type = types.int;
                      description = "Logical Y, i.e. scaled pixels.";
                    };
                  };
                }
              );
              default = null;
              description = "Position in the global logical coordinate space.";
            };
            variableRefreshRate = mkOption {
              type = types.bool;
              default = false;
              description = "Enable VRR on this output.";
            };
            variableRefreshRateOnDemand = mkOption {
              type = types.bool;
              default = false;
              description = "Only enable VRR for windows matching the variable-refresh-rate window rule.";
            };
            focusAtStartup = mkOption {
              type = types.bool;
              default = false;
              description = "Focus this output on niri startup.";
            };
            backgroundColor = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "#003300";
              description = "Background colour drawn behind workspaces.";
            };
            backdropColor = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "#001100";
              description = "Colour shown between workspaces and in the overview.";
            };
            extra = mkOption {
              type = types.nullOr types.lines;
              default = null;
              description = "Extra raw KDL lines inside this output block.";
            };
          };
        }
      );
    };

    layout = mkOption {
      default = { };
      description = "The top-level `layout` section. Unset fields fall back to niri's compiled defaults.";
      type = types.submodule {
        options = {
          gaps = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            description = "Gap between windows and the screen edge, in logical pixels.";
          };
          centerFocusedColumn = mkOption {
            type = types.nullOr (
              types.enum [
                "never"
                "always"
                "on-overflow"
              ]
            );
            default = null;
            description = "Whether to centre the focused column.";
          };
          defaultColumnWidth = mkOption {
            type = types.nullOr sizeType;
            default = null;
            description = "Width new windows open at. Empty brackets let windows choose.";
          };
          presetColumnWidths = mkOption {
            type = types.listOf sizeType;
            default = [ ];
            example = [
              { proportion = 0.33333; }
              { proportion = 0.66667; }
            ];
            description = ''
              Widths cycled by `switch-preset-column-width` (Mod+R). Defaults to
              1/3, 1/2 and 2/3 when left empty.
            '';
          };
          presetWindowHeights = mkOption {
            type = types.listOf sizeType;
            default = [ ];
            example = [
              { proportion = 0.33333; }
              { proportion = 0.66667; }
            ];
            description = ''
              Heights cycled by `switch-preset-window-height` (Mod+Ctrl+Shift+R)
              for windows stacked inside a column.
            '';
          };
          struts = mkOption {
            type = types.nullOr (
              types.submodule {
                options = {
                  left = mkOption {
                    type = types.nullOr types.ints.unsigned;
                    default = null;
                  };
                  right = mkOption {
                    type = types.nullOr types.ints.unsigned;
                    default = null;
                  };
                  top = mkOption {
                    type = types.nullOr types.ints.unsigned;
                    default = null;
                  };
                  bottom = mkOption {
                    type = types.nullOr types.ints.unsigned;
                    default = null;
                  };
                };
              }
            );
            default = null;
            description = "Reserve space at the screen edges, e.g. for a layer-shell bar.";
          };
          extra = mkOption {
            type = types.nullOr types.lines;
            default = null;
            description = "Extra raw KDL lines inside the `layout` section, e.g. border/focus-ring.";
          };
        };
      };
    };

    input = mkOption {
      default = { };
      description = "The top-level `input` section.";
      type = types.submodule {
        options = {
          keyboard = mkOption {
            default = { };
            type = types.submodule {
              options = {
                layout = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  example = "us";
                  description = "XKB layout, comma-separated for multiple.";
                };
                variant = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "XKB variant.";
                };
                options = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  example = "caps:escape";
                  description = "XKB options, comma-separated.";
                };
                numlock = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Enable NumLock on startup.";
                };
              };
            };
          };
          touchpad = mkOption {
            type = types.nullOr (
              types.submodule {
                options = {
                  tap = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Tap to click.";
                  };
                  dwt = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Disable while typing.";
                  };
                  dwtp = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Disable while trackpointing.";
                  };
                  drag = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Tap-and-drag.";
                  };
                  dragLock = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Keep dragging until the next tap.";
                  };
                  naturalScroll = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Invert the scroll direction.";
                  };
                  accelSpeed = mkOption {
                    type = types.nullOr types.float;
                    default = null;
                    description = "Pointer acceleration, -1.0 to 1.0.";
                  };
                  accelProfile = mkOption {
                    type = types.nullOr (
                      types.enum [
                        "adaptive"
                        "flat"
                      ]
                    );
                    default = null;
                    description = "Pointer acceleration profile.";
                  };
                  disabledOnExternalMouse = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Disable the touchpad when a mouse is plugged in.";
                  };
                  extra = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "Extra raw KDL lines inside the `touchpad` block.";
                  };
                };
              }
            );
            default = null;
            description = ''
              Touchpad settings. This whole block is replaced rather than merged
              by niri, so set it as a unit.
            '';
          };
          mouse = mkOption {
            type = types.nullOr (
              types.submodule {
                options = {
                  naturalScroll = mkOption {
                    type = types.bool;
                    default = false;
                  };
                  accelSpeed = mkOption {
                    type = types.nullOr types.float;
                    default = null;
                  };
                  accelProfile = mkOption {
                    type = types.nullOr (
                      types.enum [
                        "adaptive"
                        "flat"
                      ]
                    );
                    default = null;
                  };
                  extra = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                  };
                };
              }
            );
            default = null;
            description = "Mouse settings.";
          };
          warpMouseToFocus = mkOption {
            type = types.bool;
            default = false;
            description = "Warp the pointer to the centre of newly focused windows.";
          };
          focusFollowsMouse = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "0%";
            description = ''
              Enable focus-follows-mouse with this max-scroll-amount. "0%" makes
              it apply only to windows already fully on screen, which avoids
              surprise scrolling.
            '';
          };
          extra = mkOption {
            type = types.nullOr types.lines;
            default = null;
            description = "Extra raw KDL lines inside the `input` section.";
          };
        };
      };
    };

    floatingApps = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "^com\\.tencent\\.wechat$" ];
      description = ''
        app-id regexes to force-floating. niri already floats windows that have
        a parent (dialogs) or a fixed size (splash screens), so this is only for
        the exceptions. Find the app-id with `niri msg pick-window`.
      '';
    };

    blockOutFromScreencast = mkOption {
      type = types.listOf types.str;
      default = [ "^org\\.keepassxc\\.KeePassXC$" ];
      example = [ "^org\\.keepassxc\\.KeePassXC$" "^com\\.tencent\\.wechat$" ];
      description = ''
        app-id regexes to replace with a black rectangle in portal screencasts.
        Note this does NOT hide them from third-party screenshot tools; use a
        raw window-rule with `block-out-from "screen-capture"` for that.
      '';
    };

    highlightCastTarget = mkOption {
      type = types.bool;
      default = true;
      description = "Give the window currently being screencast a red focus ring.";
    };

    windowRules = mkOption {
      type = types.listOf types.lines;
      default = [ ];
      description = "Extra raw `window-rule { ... }` blocks, inserted verbatim.";
    };

    spawnAtStartup = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "kanshi" ];
      description = ''
        Commands to spawn at niri startup. Prefer a systemd user service for
        anything long-running, so its state can be inspected and restarted.
      '';
    };

    binds = mkOption {
      type = types.listOf types.lines;
      default = [ ];
      example = [ "Mod+Shift+O { spawn \"nwg-displays\"; }" ];
      description = ''
        Extra raw KDL bind lines. These are emitted after ./binds-default.kdl, so
        they override matching stock keys.
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Raw KDL appended at the end of the generated config, before the
        local.kdl include. Use for anything this module does not model
        (animations, overview, screenshot-path, xwayland-satellite, ...).
      '';
    };

    # -------------------------------------------------------------------------
    # Display presets
    # -------------------------------------------------------------------------
    displayPresets = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Label shown in the picker.";
            };
            run = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                Shell command lines applied in order, e.g.
                {command}`niri msg output DP-1 off`. Each is run through
                `sh -c`, so quoting and `&&` work as usual. Failures are
                collected and reported in the confirmation notification.

                {command}`$INTERNAL` and {command}`$EXTERNAL` are exported and
                name the internal panel and the external display, so presets keep
                working when connectors are renumbered (DP-1 to DP-2 and so on).
              '';
            };
          };
        }
      );
      default = [ ];
      description = ''
        Display presets offered by the quick switcher. Left empty by default:
        output names, modes and scales are hardware-specific, so a host is
        expected to supply its own.

        niri has no output mirroring, so "mirror" cannot be a preset; see
        `wl-mirror` in niri's wiki if that is needed for presentations.
      '';
      example = lib.literalExpression ''
        [
          {
            name = "Internal only";
            run = [ "niri msg output DP-1 off" "niri msg output eDP-1 position set 0 0" ];
          }
        ]
      '';
    };

    displayPresetKey = mkOption {
      type = types.str;
      default = "Mod+P";
      description = ''
        Key that opens the display preset picker. Only bound when
        {option}`displayPresets` is non-empty. Note niri's wiki uses Mod+P for
        a wl-mirror helper; that snippet is unnecessary here, since
        {option}`mirrorPresets` covers it.
      '';
    };

    mirrorPresets = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Also offer wl-mirror presets - "Mirror · external onto internal", the
        reverse, and "Stop mirroring" - after {option}`displayPresets`.
        Only has an effect once {option}`displayPresets` is non-empty; with a
        single output the entries resolve to nothing and do nothing.

        niri has no output cloning, so these render the source output fullscreen
        on the target through wl-mirror. Applying any preset stops an active
        mirror first, which is also what "Stop mirroring" relies on.
      '';
    };

    # -------------------------------------------------------------------------
    # Wayle
    # -------------------------------------------------------------------------
    wayle = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Run the Wayle shell alongside niri. Wayle supplies the bar, notification
          daemon, OSD, wallpaper engine and StatusNotifier tray host - on a niri
          session nothing else competes for those roles, unlike on Plasma where
          plasmashell already owns org.freedesktop.Notifications.
        '';
      };

      package = lib.mkPackageOption pkgs "wayle" { };

      autoInstallDependencies = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Let Wayle's module install the soft dependencies your config needs
          (awww for the wallpaper engine, wallust/matugen for theming).
        '';
      };

      settings = mkOption {
        type = (pkgs.formats.toml { }).type;
        default = { };
        description = ''
          Wayle configuration, serialised to ~/.config/wayle/config.toml. This is
          the shell's entire config surface; see https://wayle.app/config/.

          Merged over this module's defaults with recursiveUpdate, which replaces
          lists wholesale - so re-declare a whole list, for example
          {option}`rabit.home.niri-wayle.wayle.settings.bar.layout`, when
          changing it.
        '';
        example = lib.literalExpression ''
          {
            bar.layout = [
              {
                monitor = "DP-1";
                left = [ "dashboard" ];
                center = [ "clock" ];
                right = [ "niri-workspaces" "volume" "battery" ];
              }
            ];
            styling = {
              theme-provider = "wallust";
              palette.bg = "#16161e";
            };
            osd.monitor = "DP-1";
          }
        '';
      };
    };
  };

  config = mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isLinux) {
    xdg.configFile."niri/config.kdl".text = generated;

    # On PATH as well, so `niri-display-preset status` is usable from a bar
    # module or a shell. wl-mirror backs the mirror presets.
    home.packages = lib.optionals hasDisplayPresets (
      [ presetScript ] ++ lib.optional cfg.mirrorPresets pkgs.wl-mirror
    );

    services.wayle = mkIf cfg.wayle.enable {
      enable = true;
      inherit (cfg.wayle) package autoInstallDependencies;
      settings = lib.recursiveUpdate defaultWayleSettings cfg.wayle.settings;
    };
  };
}
