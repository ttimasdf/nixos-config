{ self, inputs, config, lib, ... }:
let
  # mapAttrsMaybe & forAllNixFiles taken from
  # https://github.com/srid/nixos-unified/blob/master/nix/modules/flake-parts/autowire.nix

  /**
    mapAttrsMaybe: Apply a function to all attributes and filter out null results

    Parameters:
      f: Function to apply to each attribute (name -> value -> lib.nameValuePair name value | null)
      attrs: Attribute set to process

    Returns: Attribute set containing only non-null results from the mapping function
  */
  mapAttrsMaybe = f: attrs:
    lib.pipe attrs [
      (lib.mapAttrsToList f)        # Convert attrs to list of name-value pairs
      (builtins.filter (x: x != null))  # Filter out null values
      builtins.listToAttrs          # Convert back to attribute set
    ];
  /**
    forAllNixFiles: Recursively process all .nix files in a directory

    Parameters:
      dir: Directory path to scan for .nix files
      f: Function to apply to each found .nix file (path -> value)

    Returns: Attribute set where keys are file names (without .nix extension)
            and values are the result of applying f to each file
   */
  forAllNixFiles = dir: f:
    if builtins.pathExists dir then
      lib.pipe dir [
        builtins.readDir  # Read directory contents
        (mapAttrsMaybe (fn: type:
          if type == "regular" then
            # Handle regular .nix files
            let name = lib.removeSuffix ".nix" fn; in
            if name != fn then
              # File has .nix extension, process it
              lib.nameValuePair name (f "${dir}/${fn}")
            else
              # File doesn't have .nix extension, skip
              null
          else if type == "directory" && builtins.pathExists "${dir}/${fn}/default.nix" then
            # Handle directories with default.nix files
            lib.nameValuePair fn (f "${dir}/${fn}")
          else
            # Skip other file types and directories without default.nix
            null
        ))
      ] else { };

  /**
    flattenPkgs: Recursively flatten nested package structures into a flat attribute set

    Parameters:
      attrs: Nested attribute set containing packages (derivations) and sub-attribute sets

    Returns: Flat attribute set where all derivations are at the top level
  */
  flattenPkgs = attrs: lib.foldl lib.recursiveUpdate { } (
    lib.mapAttrsToList (name: value:
      if lib.isDerivation value then
        # If value is a derivation, include it directly
        { "${name}" = value; }
      else if lib.isAttrs value then
        # If value is an attribute set, recursively flatten it
        flattenPkgs value
      else
        # Skip non-derivation, non-attribute values
        { }
    ) attrs
  );
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
      forAllNixFiles "${self}/overlays"
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
    packages = flattenPkgs custom_packages;

    # Alternative package export (commented out):
    # packages = custom_packages // {
    #   # Enables 'nix run' to activate.
    #   default = self'.packages.activate;
    # };
  };
}
