{ flake, pkgs, lib, config, modulesPath, ... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;

  # The live CD autologs in as this user; its desktop gets the install manual.
  liveUser = "nixos";

  installManualSrc = ../../docs/install.md;
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
      ${installManualSrc} > $out
  '';

  cfgISO = {
    # system.build.image = config.system.build.isoImage;
    # image.extension = if config.isoImage.compressImage then "iso.zst" else "iso";

    isoImage.appendToMenuLabel = " Live CD:";
    rabit.nixos.myusers = [ liveUser ];

    # First-install helper and its manual, so a freshly booted ISO can set up a
    # new host without leaving the live session.
    environment.systemPackages = [ pkgs."nixos-install-config" ];
    environment.etc."nixos-install-manual.md".source = installManualSrc;
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
            ${installManualSrc} "$liveDesktop/INSTALL.md"
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
