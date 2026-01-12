# https://github.com/nix-community/nixos-generators/blob/master/README.md#using-as-a-nixos-module
{ flake, pkgs, lib, config, ... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;
  inherit (flake.inputs) nixos-generators;

  fmt_iso = {
    formatAttr = "isoImage";
    fileExtension = ".iso";
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

    formatConfigs.minimal-iso = { config, pkgs, lib, modulesPath, options, ... }: {
      imports = [
        "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
        "${modulesPath}/installer/cd-dvd/latest-kernel.nix"
      ];

      boot.supportedFilesystems.zfs = lib.mkForce true;
      boot.zfs.package = pkgs.zfs_2_4;
      boot.supportedFilesystems.bcachefs = true;
    } // fmt_iso;
  };
}
