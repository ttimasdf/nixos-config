# List of users for darwin or nixos system and their top-level configuration.
{ flake, pkgs, lib, config, ... }:
let
  inherit (flake.inputs) self;
  inherit (self) rabit-lib;
  # Home modules will be imported by the Home Manager; we simply pass the directory path here.
  homePaths = rabit-lib.forAllNixFiles (self + /configurations/home) (path: path);
  # User modules should be imported directly by us.
  # Currently, user modules are simply plain attrSets.
  # If we need to support functions later, use (path: import path { inherit flake pkgs lib config; }).
  userImports = rabit-lib.forAllNixFiles (self + /configurations/users) (path: import path { inherit flake pkgs lib config; });
in
{
  options = {
    rabit.nixos.myusers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of usernames";
      defaultText = "All users under ./configuration/home are included by default";
      default = lib.attrNames homePaths;
    };
  };

  config = {
    # For home-manager to work.
    # https://github.com/nix-community/home-manager/issues/4026#issuecomment-1565487545
    users.users = rabit-lib.mapListToAttrs config.rabit.nixos.myusers (name:
      let
        hasUserImport = lib.hasAttr name userImports;
        cfg = lib.warnIf (!hasUserImport) "User '${name}' has no user configuration under ./configurations/users"
          (if hasUserImport then userImports.${name} else {});
      in
      cfg // lib.optionalAttrs pkgs.stdenv.isDarwin {
        home = "/Users/${name}";
      } // lib.optionalAttrs pkgs.stdenv.isLinux {
        isNormalUser = true;
      });

    # Enable home-manager for our user
    home-manager.users = rabit-lib.mapListToAttrs config.rabit.nixos.myusers (name:
      let
        hasHomePath = lib.hasAttr name homePaths;
      in
      {
        imports = lib.throwIf (!hasHomePath) "User '${name}' has no home configuration under ./configurations/home"
          (if hasHomePath then [ homePaths.${name} ] else []);
      });

    # All users can add Nix caches.
    nix.settings.trusted-users = [
      "root"
    ] ++ config.rabit.nixos.myusers;
  };
}
