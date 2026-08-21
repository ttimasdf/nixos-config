{ flake, lib, config, ... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;
  inherit (flake.inputs) rabit-nix-packages private-module;

  currentSystem = config.nixpkgs.hostPlatform.system;

  packagesForCurrentSystem =
    inputName:
    let
      input = flake.inputs.${inputName};
    in
    if builtins.hasAttr currentSystem input.packages then
      input.packages.${currentSystem}
    else
      throw "${inputName}.packages is missing system '${currentSystem}'";

  localPackages =
    final: _prev:
    rabit-lib.forAllNixFiles "${self}/packages" (packagePath: lib.callPackageWith final packagePath { });
  privatePackages = _final: _prev: packagesForCurrentSystem "private-module";
in
{
  nixpkgs.overlays = [
    # The package overlay also supplies compatibility dependencies required by
    # wuying-cloud-desktop. Existing-package overrides remain explicit.
    rabit-nix-packages.overlays.packages
    rabit-nix-packages.overlays.ark
    rabit-nix-packages.overlays.clash-verge-rev
    rabit-nix-packages.overlays.cockpit-zfs
    rabit-nix-packages.overlays.fcitx5-rime-ice
    rabit-nix-packages.overlays.ghidra
    rabit-nix-packages.overlays.kscreen
    rabit-nix-packages.overlays.nvtop
    rabit-nix-packages.overlays.qt68
    rabit-nix-packages.overlays.wps
    rabit-nix-packages.overlays.xxzip-natspec
  ]
  ++ (builtins.attrValues private-module.overlays)
  ++ [
    localPackages
    privatePackages
  ];
}
