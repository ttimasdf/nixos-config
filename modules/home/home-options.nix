# User configuration module
{ config, lib, ... }:
{
  options = {
    rabit.home.me = {
      username = lib.mkOption {
        type = lib.types.str;
        description = "Your username as shown by `id -un`";
      };
      fullname = lib.mkOption {
        type = lib.types.str;
        description = "Your full name for use in Git config";
      };
      email = lib.mkOption {
        type = lib.types.str;
        description = "Your email for use in Git config";
      };
      git = {
        sshSigningKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "SSH public key for signing Git commits";
        };
        allowedSigners = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ config.rabit.home.me.email ];
          description = "Allowed signers for Git commit verification";
        };
      };
    };
  };
  config = {
    home.username = config.rabit.home.me.username;
  };
}
