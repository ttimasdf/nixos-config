{ self, inputs, config, lib, ... }:
let
  # rabit-lib = import "${self}/modules/flake/lib.nix" { inherit self lib; };
  inherit (self) rabit-lib;
in
{
  perSystem = { system, config, self', inputs', pkgs, ... }:
  let
    # Arguments to pass to overlay files
    overlay_args = {
      inherit pkgs lib;
      flake = {
        inherit config system;
        self = self';
        inputs = inputs';
      };
    };

    # Load all overlays from the overlays directory
    overlays =
      rabit-lib.forAllNixFiles "${self}/overlays"
        (fn: import fn overlay_args);

    # Create callPackage function that includes both system packages and custom packages
    callPackage = pkgs.lib.callPackageWith (pkgs // custom_packages);

    # Load all custom packages from the packages directory
    custom_packages = pkgs.lib.packagesFromDirectoryRecursive {
      callPackage = callPackage;
      directory = "${self}/packages";
    };
  in
  {
    # Configure the package set for this system
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;  # Allow unfree packages
      overlays = builtins.attrValues overlays; # Apply all overlays
      # ++ [ (_: _: custom_packages) ];  # Alternative: include custom packages as overlay
    };

    # Export flattened packages for this flake
    packages = rabit-lib.flattenPkgs custom_packages;

    # Alternative package export (commented out):
    # packages = custom_packages // {
    #   # Enables 'nix run' to activate.
    #   default = self'.packages.activate;
    # };
  };
}
