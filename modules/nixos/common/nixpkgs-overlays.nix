{ flake, lib, config, pkgs, ... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;
  inherit (flake.inputs) private-module;

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

  # Manually call packages, as using self.packages here would lead to infinite recursion
  packages =
    final: prev:
      rabit-lib.forAllNixFiles "${self}/packages"
        (fn: lib.callPackageWith final fn { });
  privatePackages = final: prev: packagesForCurrentSystem "private-module";
  # llmagentsPackages = final: prev: packagesForCurrentSystem "llm-agents";
in
{
  # Map the list of file paths to a list of overlay functions
  nixpkgs.overlays =
    (builtins.attrValues self.overlays)
    ++ (builtins.attrValues private-module.overlays)
    # ++ (builtins.attrValues llm-agents.overlays)
    ++ [ packages privatePackages ];
}
