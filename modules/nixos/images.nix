{ flake, pkgs, lib, config, modulesPath, ... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;

  # The live CD autologs in as this user; its desktop gets the install manual.
  liveUser = "nixos";

  # Extra host closures to preload into the ISO store, so those hosts can be
  # rebuilt or installed from the live ISO without downloading their closure.
  # Names refer to `nixosConfigurations` outputs. Read from the environment so
  # the host is chosen on the nixos-rebuild command line (requires --impure):
  #   RABIT_ISO_PACK_HOSTS="viscacha MNIX" nixos-rebuild build-image ... --impure
  # Space- or comma-separated. Empty (the default in pure evaluation) packs
  # nothing, so ordinary ISO builds are unaffected.
  packedHostNames =
    lib.filter (name: name != "")
      (lib.splitString " " (lib.replaceStrings [ "," ] [ " " ] (lib.maybeEnv "RABIT_ISO_PACK_HOSTS" "")));

  packedHostStoreContents = lib.warnIf (packedHostNames != [ ])
    "RABIT_ISO_PACK_HOSTS: preloading host closures into the ISO store: ${lib.concatStringsSep ", " packedHostNames}"
    (map
      (name:
        let
          configs = self.nixosConfigurations or { };
        in
        if builtins.hasAttr name configs then
          configs.${name}.config.system.build.toplevel
        else
          throw "RABIT_ISO_PACK_HOSTS: '${name}' is not a nixosConfigurations output")
      packedHostNames);

  # The flake source plus every source reachable in its input graph, so the
  # flake baked onto the ISO can be evaluated with no network access. Flake
  # inputs expose their own `inputs`, so this walks transitive inputs too;
  # dedup by store path also breaks the input cycle. ~0.2 GiB, dominated by
  # the nixpkgs source.
  flakeInputPaths =
    let
      walk = seen: node:
        let
          path = node.outPath or null;
          isNew = path == null || !(builtins.elem path seen);
          seen' = if path == null then seen else seen ++ [ path ];
        in
        if isNew then builtins.foldl' walk seen' (builtins.attrValues (node.inputs or { })) else seen;
    in
    walk [ ] { inputs = flake.inputs; };

  # Direct input name -> store path, so the installer can pin the baked flake
  # to exactly these sources with --override-input and never fetch anything.
  flakeInputManifest = lib.mapAttrs (_: input: input.outPath) (builtins.removeAttrs flake.inputs [ "self" ]);

  # A filtered snapshot of the flake source to bake onto the ISO. Drops VCS and
  # build junk via cleanSourceFilter (including `.git` and `result`), plus the
  # private checkout, the public-packages submodule, generated artifacts and
  # editor caches. The installer copies this to the target, so it should hold
  # only what evaluation needs.
  flakeSource = lib.cleanSourceWith {
    name = "nixos-config-source";
    src = self;
    filter =
      path: type:
      let
        base = baseNameOf (toString path);
      in
      lib.cleanSourceFilter path type
      && !(builtins.elem base [
        ".direnv"
        ".ruff_cache"
        ".vscode"
        "__pycache__"
        "nix-paths.txt"
        "private"
        "public-packages"
        "source"
        "viscacha-tree.html"
      ]);
  };

  offlineFlakeStoreContents = lib.unique ([ flakeSource ] ++ flakeInputPaths);

  # Input name -> baked store path, consumed by nixos-rabit-install to pin the
  # baked flake with --override-input. This lives in the store, not /etc.
  flakeInputManifestFile = pkgs.writeText "nixos-config-inputs"
    (lib.concatStringsSep "\n" (lib.mapAttrsToList (name: path: "${name} ${path}") flakeInputManifest) + "\n");

  # The installer preconfigured for the live ISO. It carries the baked flake
  # source and the input manifest (both plain store paths) via environment
  # variables and delegates to the generic package.
  nixosRabitInstall = pkgs.writeShellApplication {
    name = "nixos-rabit-install";
    text = ''
      export RABIT_ISO_BAKED_FLAKE=${flakeSource}
      export RABIT_ISO_BAKED_INPUTS=${flakeInputManifestFile}
      exec ${pkgs."nixos-rabit-install"}/bin/nixos-rabit-install "$@"
    '';
  };

  # Placeholder the manual uses for the host name.
  manualHostPattern = "\${HOST}";

  installManualSrc = ../../docs/install.md;

  # Substitute the manual's host placeholder with the first host packed into
  # the ISO (RABIT_ISO_PACK_HOSTS), if any, so the on-ISO instructions match
  # what the ISO actually carries. Left as-is when nothing is packed.
  installManualMd =
    if packedHostNames == [ ] then
      installManualSrc
    else
      pkgs.runCommand "nixos-install-manual.md" { } ''
        substitute ${installManualSrc} $out \
          --replace-fail ${lib.escapeShellArg manualHostPattern} ${lib.escapeShellArg (lib.head packedHostNames)}
      '';

  installManualHtml = pkgs.runCommand "nixos-install-manual.html"
    {
      nativeBuildInputs = [ pkgs.pandoc ];
    } ''
    cat > manual-header.html <<'HTML'
    <style>
      body { max-width: 54rem; margin: 2.5rem auto; padding: 0 1.25rem;
             font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
             line-height: 1.55; color: #1a1a1a; }
      h1, h2, h3 { line-height: 1.25; }
      code { background: #f2f2f2; padding: .1em .3em; border-radius: 4px; }
      pre { background: #f2f2f2; padding: .8rem 1rem; border-radius: 6px;
            overflow-x: auto; }
      pre code { background: none; padding: 0; }
      table { border-collapse: collapse; }
      th, td { border: 1px solid #ccc; padding: .35rem .6rem; text-align: left; }
      blockquote { border-left: 4px solid #ccc; margin-left: 0; padding-left: 1rem;
                   color: #444; }
    </style>
    HTML
    pandoc \
      --from gfm \
      --to html5 \
      --standalone \
      --include-in-header manual-header.html \
      --metadata title="KnownRabbit NixOS - first install" \
      --metadata lang=en \
      ${installManualMd} > $out
  '';

  cfgISO = {
    # system.build.image = config.system.build.isoImage;
    # image.extension = if config.isoImage.compressImage then "iso.zst" else "iso";

    isoImage.appendToMenuLabel = " Live CD:";
    rabit.nixos.myusers = [ liveUser ];

    # Preload the requested host closures, if any (see RABIT_ISO_PACK_HOSTS),
    # plus the flake source and its inputs so a host can be installed from the
    # ISO with no network access. Merges with the default, which is this
    # system's own toplevel.
    isoImage.storeContents = packedHostStoreContents ++ offlineFlakeStoreContents;

    # First-install helper (preconfigured with the baked flake and inputs) and
    # its manual, so a freshly booted ISO can set up a new host offline.
    environment.systemPackages = [ nixosRabitInstall ];
    environment.etc."nixos-install-manual.md".source = installManualMd;
    environment.etc."nixos-install-manual.html".source = installManualHtml;

    # Drop the rendered manual onto the live user's desktop.
    system.activationScripts.nixos-install-manual = {
      deps = [ "users" ];
      text = ''
        liveUser=${lib.escapeShellArg liveUser}
        if ${pkgs.coreutils}/bin/id "$liveUser" >/dev/null 2>&1; then
          liveGroup="$(${pkgs.coreutils}/bin/id -gn "$liveUser")"
          liveDesktop="/home/$liveUser/Desktop"
          ${pkgs.coreutils}/bin/install -D -m 0644 -o "$liveUser" -g "$liveGroup" \
            ${installManualHtml} "$liveDesktop/INSTALL.html"
          ${pkgs.coreutils}/bin/install -D -m 0644 -o "$liveUser" -g "$liveGroup" \
            ${installManualMd} "$liveDesktop/INSTALL.md"
        fi
      '';
    };
  };

  cfgFS = {
    boot.supportedFilesystems.zfs = lib.mkForce true;
    boot.supportedFilesystems.bcachefs = true;
  };

  cfgCLISpecialisation = {
    # When creating GRUB menu, buildMenuGrub2 calls `lib.mapAttrsToList`
    # which sorts alphabetically by the key, prepend `zzz_` to make sure
    # this specialisation always at the bottom of the GRUB menu.
    zzz_cli.configuration =
      { config, ... }:
      {
        isoImage.showConfiguration = true;
        isoImage.configurationName = "CLI";
      };
  };
in
{
  config.image.modules = {
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/installer/cd-dvd/iso-image.nix
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/installer/cd-dvd/latest-kernel.nix

    iso-minimal = rabit-lib.mergeAttrsList [
      {
        imports = [
          "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
          "${modulesPath}/installer/cd-dvd/latest-kernel.nix"
        ];
      }
      cfgFS
      cfgISO
    ];

    iso-gnome = rabit-lib.mergeAttrsList [
      {
        imports = [
          "${modulesPath}/installer/cd-dvd/installation-cd-base.nix"
          "${modulesPath}/installer/cd-dvd/latest-kernel.nix"
        ];
        isoImage.edition = "gnome";
        isoImage.showConfiguration = lib.mkDefault false;
        specialisation = {
          gnome.configuration =
            { config, ... }:
            {
              imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-graphical-gnome.nix" ];
              isoImage.configurationName = "GNOME";
              isoImage.showConfiguration = true;
            };
        } // cfgCLISpecialisation;
      }
      cfgFS
      cfgISO
    ];

    iso-xfce = rabit-lib.mergeAttrsList [
      {
        # https://wiki.nixos.org/wiki/Xfce
        # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/x11/desktop-managers/xfce.nix
        imports = [
          "${modulesPath}/installer/cd-dvd/installation-cd-base.nix"
          "${modulesPath}/installer/cd-dvd/latest-kernel.nix"
        ];
        isoImage.edition = "xfce";
        isoImage.showConfiguration = lib.mkDefault false;
        specialisation = {
          xfce.configuration =
            { config, ... }:
            {
              imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-graphical-base.nix" ];
              isoImage.configurationName = "XFCE";
              isoImage.showConfiguration = true;

              nixpkgs.config.pulseaudio = true;

              services.xserver.desktopManager = {
                xterm.enable = false;
                xfce.enable = true;
              };
              services.displayManager.defaultSession = "xfce";

              programs.thunar.plugins = with pkgs; [
                thunar-archive-plugin
                thunar-volman
              ];

              environment.xfce.excludePackages = with pkgs; [
                parole
              ];
            };
        } // cfgCLISpecialisation;
      }
      cfgFS
      cfgISO
    ];
  };
}
