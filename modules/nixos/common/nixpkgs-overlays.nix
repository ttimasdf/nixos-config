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
  # repository. Apply every distinct public overlay: `default` aliases
  # `packages`, while `libtiff5` and `qt5webengine` are already composed into
  # the package overlay for wuying-cloud-desktop.
  knownRabbitOverlays = [
    known-rabbit-packages.overlays.packages
  ]
  ++ builtins.attrValues (
    builtins.removeAttrs known-rabbit-packages.overlays [
      "default"
      "packages"
      "libtiff5"
      "qt5webengine"
    ]
  );
in
{
  nixpkgs.overlays =
    knownRabbitOverlays
    ++ (builtins.attrValues private-module.overlays)
    ++ [
      localPackages
      privatePackages
    ];
}
