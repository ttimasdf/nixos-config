{ flake, lib, config, pkgs, ... }:
let
  inherit (flake) self;
  overlaysPath = self + "/overlays";

  # Recursively find all .nix files in the overlays directory
  overlayFiles = lib.filesystem.listFilesRecursive overlaysPath;

  # Import each file and apply the necessary arguments
  importOverlay = path:
    let
      imported_module = import path;
    in
    # The overlay file is a function that takes flake inputs
    # and returns the final overlay function.
      imported_module { inherit flake lib config; };

  overlays = (map importOverlay overlayFiles);

  packagesPath = self + "/packages";
  packages =
    final: prev:
    (prev.lib.packagesFromDirectoryRecursive {
      callPackage = prev.lib.callPackageWith final;
      directory = packagesPath;
    });

in
{
  # Map the list of file paths to a list of overlay functions
  nixpkgs.overlays = overlays ++ [ packages ];
}
