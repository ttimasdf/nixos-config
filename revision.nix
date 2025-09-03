# conditional-revision.nix
{ config, lib, ... }:

let
  # Get the value of NIXOS_LABEL, defaulting to an empty string "" if it's not set.
  envLabelSuffix = builtin.getEnv "NIXOS_LABEL_SUFFIX";
in
{
  config = {
    assertions = [
      {
        assertion = envLabelSuffix != "";
        message = "NIXOS_LABEL_SUFFIX should not be empty";
      }
    ];
    # system.configurationRevision = lib.mkDefault envLabelSuffix;
  };
}