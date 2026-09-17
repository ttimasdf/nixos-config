# ISO image variants (`config.image.modules`), plus the offline install content
# they carry. Hosts import this as `self.nixosModules.images`.
{ flake, pkgs, lib, modulesPath, ... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;

  liveUser = "nixos";

  baked = import ./baked-flake.nix { inherit flake pkgs lib; };
  manual = import ./install-manual.nix { inherit pkgs lib; };
  content = import ./iso-content.nix { inherit pkgs lib baked manual liveUser; };
  inherit (content) mkCfgISOContent;

  cfgISO = {
    # system.build.image = config.system.build.isoImage;
    # image.extension = if config.isoImage.compressImage then "iso.zst" else "iso";

    isoImage.appendToMenuLabel = " Live CD:";
    rabit.nixos.myusers = [ liveUser ];
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

  # https://wiki.nixos.org/wiki/Xfce
  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/x11/desktop-managers/xfce.nix
  xfceBase = {
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
  };

  # The host derivations that depend on hardware-configuration.nix, and so are
  # regenerated -- and therefore rebuilt -- by nixos-install. Their inputs are
  # what a packed ISO has to be able to satisfy; delta-probe.nix walks them.
  deltaRootAttrs = [
    "bootStage1"
    "bootStage2"
    "earlyMountScript"
    "etc"
    "etcActivationCommands"
    "etcBasedir"
    "etcMetadataImage"
    "fileSystems"
    "initialRamdisk"
    "initialRamdiskSecretAppender"
    "inhibitSwitch"
    "installBootLoader"
    "modulesClosure"
    "separateActivationScripts"
    "setEnvironment"
    "uki"
    "units"
  ];

  hostDeltaRoots =
    host:
    let
      hostConfig = self.nixosConfigurations.${host}.config;
      build = hostConfig.system.build;
      # `specialisation.<name>.configuration` is the extended NixOS config of
      # the specialisation, not a plain module (see specialisation.nix).
      specialisations = lib.mapAttrsToList (
        _: spec: spec.configuration.system.build.toplevel
      ) (hostConfig.specialisation or { });
    in
    [ build.toplevel ]
    ++ specialisations
    ++ map (attr: build.${attr}) (lib.filter (attr: builtins.hasAttr attr build) deltaRootAttrs);

  mkXfce =
    { packedHost ? null, hostToplevel ? null, deltaRoots ? [ ] }:
    rabit-lib.mergeAttrsList [
      xfceBase
      cfgFS
      cfgISO
      (mkCfgISOContent { inherit packedHost hostToplevel deltaRoots; })
    ];

  # One XFCE installer ISO per host, so a host's closure can be carried and
  # installed offline: `--image-variant iso-xfce-install-<host>`.
  packedVariants = lib.listToAttrs (map
    (host: lib.nameValuePair "iso-xfce-install-${host}" (mkXfce {
      packedHost = host;
      hostToplevel = self.nixosConfigurations.${host}.config.system.build.toplevel;
      deltaRoots = map (drv: drv.drvPath) (hostDeltaRoots host);
    }))
    (builtins.attrNames (self.nixosConfigurations or { })));
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
      (mkCfgISOContent { })
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
      (mkCfgISOContent { })
    ];

    iso-xfce = mkXfce { };
  }
  // packedVariants;
}
