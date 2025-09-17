# This module adds a suffix to the NixOS system label.
# The suffix is read from the `nixos-version-hint.txt` file in the root of the repository.
# This is useful for differentiating between builds with the same version number.
#
# To use this feature:
# 1. Create a file named `nixos-version-hint.txt` in the root of the repository.
# 2. Add your desired suffix to this file.
#    For example: `my-custom-build`
# 3. The build will fail if the file is empty or contains `changeme`.
{ flake, config, lib, ... }:

let
  inherit (flake.inputs) self;
  cfg = config.system.nixos;
  labelSuffix = builtins.readFile (toString self + "/nixos-version-hint.txt");
  sanitizedSuffix = builtins.replaceStrings [ "\n" ] [ "" ] labelSuffix;
in
{
  config = {
    assertions = [
      {
        assertion = sanitizedSuffix != "";
        message = "nixos-version-hint.txt should not be empty";
      }
      {
        assertion = sanitizedSuffix != "changeme";
        message = "Please change the content of nixos-version-hint.txt before building";
      }
    ];
    system.configurationRevision = self.rev or self.dirtyRev;
    system.nixos.label = lib.maybeEnv "NIXOS_LABEL" (
        lib.concatStringsSep "-" (
          (lib.sort (x: y: x < y) cfg.tags) ++ [ (lib.maybeEnv "NIXOS_LABEL_VERSION" cfg.version) sanitizedSuffix ]
        )
      );
  };
}
