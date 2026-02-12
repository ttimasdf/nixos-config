{ flake, pkgs, lib, config, modulesPath,... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;

  cfgISO = {
    # system.build.image = config.system.build.isoImage;
    # image.extension = if config.isoImage.compressImage then "iso.zst" else "iso";

    isoImage.appendToMenuLabel = " Live CD:";
    rabit.nixos.myusers = ["nixos"];
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
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/virtualisation/proxmox-image.nix

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
