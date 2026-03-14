{ flake, lib, config, pkgs, ... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;
  inherit (flake.inputs) private-module llm-agents;

  currentSystem = lib.trace "FIXME: currentSystem pinned to x86_64-linux" "x86_64-linux";

  # Manually call packages, as using self.packages here would lead to infinite recursion
  packages =
    final: prev:
      rabit-lib.forAllNixFiles "${self}/packages"
        (fn: lib.callPackageWith final fn { });
  privatePackages = final: prev: private-module.packages."${currentSystem}";
  llmagentsPackages = final: prev: llm-agents.packages."${currentSystem}";
in
{
  # Map the list of file paths to a list of overlay functions
  nixpkgs.overlays =
    (builtins.attrValues self.overlays)
    ++ (builtins.attrValues private-module.overlays)
    ++ (builtins.attrValues llm-agents.overlays)
    ++ [ packages privatePackages llmagentsPackages ];
}
