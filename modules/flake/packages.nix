{ self, inputs, config, lib, ... }:
let
  ## copied from https://github.com/srid/nixos-unified/blob/master/nix/modules/flake-parts/autowire.nix
  # Combine mapAttrs' and filterAttrs
  #
  # f can return null if the attribute should be filtered out.
  mapAttrsMaybe = f: attrs:
    lib.pipe attrs [
      (lib.mapAttrsToList f)
      (builtins.filter (x: x != null))
      builtins.listToAttrs
    ];
  forAllNixFiles = dir: f:
    if builtins.pathExists dir then
      lib.pipe dir [
        builtins.readDir
        (mapAttrsMaybe (fn: type:
          if type == "regular" then
            let name = lib.removeSuffix ".nix" fn; in
            if name != fn then
              lib.nameValuePair name (f "${dir}/${fn}")
            else
              null
          else if type == "directory" && builtins.pathExists "${dir}/${fn}/default.nix" then
            lib.nameValuePair fn (f "${dir}/${fn}")
          else
            null
        ))
      ] else { };
in
{
  perSystem = { system, config, self', inputs', pkgs, ... }:
  let
    overlay_args = {
      inherit pkgs lib;
      flake = {
        inherit config system;
        self = self';
        inputs = inputs';
      };
    };

    overlays =
      forAllNixFiles "${self}/overlays"
        (fn: import fn overlay_args);

    callPackage = pkgs.lib.callPackageWith (pkgs // custom_packages);
    custom_packages = pkgs.lib.packagesFromDirectoryRecursive {
      callPackage = callPackage;
      directory = "${self}/packages";
    };

    flattenPkgs = attrs: lib.foldl lib.recursiveUpdate { } (
      lib.mapAttrsToList (name: value:
        if lib.isDerivation value then
          { "${name}" = value; }
        else if lib.isAttrs value then
          flattenPkgs value
        else
          { }
      ) attrs
    );
  in
  {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = builtins.attrValues overlays; # ++ [ (_: _: custom_packages) ];
    };

    packages = flattenPkgs custom_packages;
    # packages = custom_packages // {
    #   # Enables 'nix run' to activate.
    #   default = self'.packages.activate;
    # };
  };
}
