# https://github.com/nix-community/nixos-generators/blob/master/README.md#using-as-a-nixos-module
{ flake, pkgs, lib, config, ... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;
  inherit (flake.inputs) nixos-generators;

  cfgISO = {
    formatAttr = "isoImage";
    fileExtension = ".iso";
    isoImage.appendToMenuLabel = " Live CD:";
    rabit.nixos.myusers = ["nixos"];
  };

  cfgFS = {
    boot.supportedFilesystems.zfs = lib.mkForce true;
    boot.zfs.package = lib.trace "TODO: ZFS package pinned to zfs_2_4" pkgs.zfs_2_4;
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
  imports = [
    nixos-generators.nixosModules.all-formats
  ];
  config = {
    # https://github.com/nix-community/nixos-generators/blob/master/formats/iso.nix
    # https://github.com/nix-community/nixos-generators/blob/master/formats/install-iso.nix
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/installer/cd-dvd/iso-image.nix
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/installer/cd-dvd/latest-kernel.nix

    formatConfigs.minimal-iso = { config, pkgs, lib, modulesPath, options, ... }:
      rabit-lib.mergeAttrsList [
        {
          imports = [
            "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
            "${modulesPath}/installer/cd-dvd/latest-kernel.nix"
          ];
        }
        cfgFS
        cfgISO
      ];

    formatConfigs.gnome-iso = { config, pkgs, lib, modulesPath, options, ... }:
      rabit-lib.mergeAttrsList [
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

    formatConfigs.xfce-iso = { config, pkgs, lib, modulesPath, options, ... }:
      rabit-lib.mergeAttrsList [
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
