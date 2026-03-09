{ self, lib, ... }:
let
  # mapAttrsMaybe & forAllNixFiles taken from
  # https://github.com/srid/nixos-unified/blob/master/nix/modules/flake-parts/autowire.nix

  /**
    mapAttrsMaybe: Apply a function to all attributes and filter out null results

    Parameters:
      callback: Function to apply to each attribute (name -> value -> lib.nameValuePair name value | null)
      attrs: Attribute set to process

    Returns: Attribute set containing only non-null results from the mapping function
  */
  mapAttrsMaybe = callback: attrs:
    lib.pipe attrs [
      (lib.mapAttrsToList callback)        # Convert attrs to list of name-value pairs
      (builtins.filter (x: x != null))  # Filter out null values
      builtins.listToAttrs          # Convert back to attribute set
    ];
  /**
    forAllNixFiles': Recursively process all .nix files in a directory with custom index file name

    Parameters:
      dir: Directory path to scan for .nix files
      callback: Function to apply to each found .nix file (path -> value)
      indexNixFileName: Directory entry point file name to look for when indexing directories

    Returns: Attribute set where keys are file names (without .nix extension)
            and values are the result of applying callback to each file
   */
  forAllNixFiles' = dir: callback: indexNixFileName:
    if builtins.pathExists dir then
      lib.pipe dir [
        builtins.readDir  # Read directory contents
        (mapAttrsMaybe (fn: type:
          if type == "regular" then
            # Handle regular .nix files
            let name = lib.removeSuffix ".nix" fn; in
            if name != fn then
              # File has .nix extension, process it
              lib.nameValuePair name (callback "${dir}/${fn}")
            else
              # File doesn't have .nix extension, skip
              null
          else if type == "directory" && builtins.pathExists "${dir}/${fn}/${indexNixFileName}" then
            # Handle directories with an index .nix file
            lib.nameValuePair fn (callback "${dir}/${fn}")
          else
            # Skip other file types and directories without the index .nix file
            null
        ))
      ] else { };

  /**
    forAllNixFiles: Recursively process all .nix files in a directory (uses default.nix for directories)

    Parameters:
      dir: Directory path to scan for .nix files
      callback: Function to apply to each found .nix file (path -> value)

    Returns: Attribute set where keys are file names (without .nix extension)
            and values are the result of applying callback to each file
   */
  forAllNixFiles = dir: callback:
    forAllNixFiles' dir callback "default.nix";

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

  /**
    mapListToAttrs: Convert a list of strings to an attribute set by applying a function to each element.

    Parameters:
      list: A list of strings, where each string will become an attribute name.
      callback: A function to apply to each string in the list to determine the corresponding attribute value (name -> value).

    Returns: An attribute set where each name is an element from the input list and each value is the result of applying the function to that name.
  */
  mapListToAttrs = list: callback:
    lib.listToAttrs (map (name: { inherit name; value = callback name; }) list);

  /**
    findPatches: Find all .patch files in a directory and return their full paths.

    Parameters:
      patchesDir: Directory path to scan for .patch files

    Returns: List of full paths to .patch files
  */
  findPatches = patchesDir:
    lib.pipe patchesDir [
      builtins.readDir
      (lib.attrNames)
      (lib.filter (name: lib.hasSuffix ".patch" name))
      (lib.map (name: "${patchesDir}/${name}"))
    ];

  /**
    mergeAttrsList: Merge a list of attribute sets into a single attribute set using recursive update.

    Parameters:
      list: A list of attribute sets to merge

    Returns: A single attribute set containing all merged attributes.
             Later elements in the list take precedence over earlier ones.
  */
  mergeAttrsList = list: lib.foldl lib.recursiveUpdate { } list;
in
{
  config.flake = {
    rabit-lib = {
      inherit mapAttrsMaybe forAllNixFiles forAllNixFiles' flattenPkgs mapListToAttrs findPatches mergeAttrsList;
    };
  };
}
