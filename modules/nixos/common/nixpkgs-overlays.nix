{ flake, lib, config, ... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;
  inherit (flake.inputs) nix-packages private-module;

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
    nix-packages.overlays.packages
    nix-packages.overlays.ark
    nix-packages.overlays.clash-verge-rev
    nix-packages.overlays.cockpit-zfs
    nix-packages.overlays.fcitx5-rime-ice
    nix-packages.overlays.ghidra
    nix-packages.overlays.kscreen
    nix-packages.overlays.nvtop
    nix-packages.overlays.qt68
    nix-packages.overlays.wps
    nix-packages.overlays.xxzip-natspec
  ]
  ++ (builtins.attrValues private-module.overlays)
  ++ [
    localPackages
    privatePackages
  ];
}
