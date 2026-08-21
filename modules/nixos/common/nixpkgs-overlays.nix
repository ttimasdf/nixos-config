{ flake, lib, config, ... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;
  inherit (flake.inputs) known-rabbit-packages private-module;

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
    known-rabbit-packages.overlays.packages
    known-rabbit-packages.overlays.ark
    known-rabbit-packages.overlays.clash-verge-rev
    known-rabbit-packages.overlays.cockpit-zfs
    known-rabbit-packages.overlays.fcitx5-rime-ice
    known-rabbit-packages.overlays.ghidra
    known-rabbit-packages.overlays.kscreen
    known-rabbit-packages.overlays.nvtop
    known-rabbit-packages.overlays.qt68
    known-rabbit-packages.overlays.wps
    known-rabbit-packages.overlays.xxzip-natspec
  ]
  ++ (builtins.attrValues private-module.overlays)
  ++ [
    localPackages
    privatePackages
  ];
}
