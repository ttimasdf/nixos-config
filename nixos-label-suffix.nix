{ config, lib, ... }:

let
  envLabelSuffix = builtins.getEnv "NIXOS_LABEL_SUFFIX";
  cfg = config.system.nixos;
in
{
  config = {
    assertions = [
      {
        assertion = envLabelSuffix != "";
        message = "NIXOS_LABEL_SUFFIX should not be empty";
      }
    ];
    system.configurationRevision = lib.mkDefault envLabelSuffix;
    system.nixos.label = lib.maybeEnv "NIXOS_LABEL" (
        lib.concatStringsSep "-" (
          (lib.sort (x: y: x < y) cfg.tags) ++ [ (lib.maybeEnv "NIXOS_LABEL_VERSION" cfg.version) envLabelSuffix ]
        )
      );
  };
}