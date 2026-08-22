{
  flake,
  lib,
  config,
  ...
}:
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
    rabit-lib.forAllNixFiles "${self}/packages" (
      packagePath: lib.callPackageWith final packagePath { }
    );
  privatePackages = _final: _prev: packagesForCurrentSystem "private-module";

  # This configuration is the trusted reference consumer of the public package
  # repository, so it opts into the repository's complete aggregate overlay.
in
{
  nixpkgs.overlays = [
    known-rabbit-packages.overlays.all
  ]
  ++ (builtins.attrValues private-module.overlays)
  ++ [
    localPackages
    privatePackages
  ];
}
