{ flake, lib, ... }:
let
  inherit (flake) self;
  inherit (self) rabit-lib;
  inherit (flake.inputs) private-module;

  currentSystem = lib.trace "FIXME: currentSystem pinned to x86_64-linux" "x86_64-linux";

  # Manually call packages, as using self.packages here would lead to infinite recursion
  packages =
    final: prev:
    let
      stablePkgs = import flake.inputs.nixpkgs-stable {
        system = currentSystem;
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [ "qtwebengine-5.15.19" ];
        };
      };
    in
      rabit-lib.forAllNixFiles "${self}/packages"
        (fn:
          let
            packageArgs =
              if lib.hasSuffix "/packages/unicom-cloud-desktop" (toString fn) then
                { inherit stablePkgs; }
              else
                { };
          in
          lib.callPackageWith final fn packageArgs);
  privatePackages = final: prev: private-module.packages."${currentSystem}";
  # llmagentsPackages = final: prev: llm-agents.packages."${currentSystem}";
in
{
  # Map the list of file paths to a list of overlay functions
  nixpkgs.overlays =
    (builtins.attrValues self.overlays)
    ++ (builtins.attrValues private-module.overlays)
    # ++ (builtins.attrValues llm-agents.overlays)
    ++ [ packages privatePackages ];
}
