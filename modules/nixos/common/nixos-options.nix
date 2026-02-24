{ flake, config, lib, ... }:
let
  inherit (flake.inputs) self;
  inherit (self) rabit-lib;
  homePaths = rabit-lib.forAllNixFiles (self + /configurations/home) (path: path);
in
{
  options = {
    rabit.nixos = {
      http_proxy = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = config.networking.proxy.default;
        example = "http://127.0.0.1:28888";
        description = "The HTTP proxy URL to be used by the nix-daemon. This sets the `http_proxy` and `https_proxy` environment variables for the nix-daemon service.";
      };
      no_proxy = lib.mkOption {
        type = lib.types.str;
        default = "localhost,127.0.0.1,[::1],192.168.0.0/16,172.0.0.0/12,10.0.0.0/8";
        description = "The `no_proxy` environment variable to be used by the nix-daemon. Specifies a comma-separated list of hostnames, IPs, or CIDR ranges to bypass the proxy.";
      };
      myusers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "A list of usernames to be configured on the system. For each user, the system configuration is loaded from `configurations/users/` and the Home Manager configuration from `configurations/home/`. These users are also added to `nix.settings.trusted-users`.";
        example = lib.attrNames homePaths;
      };
    };
  };
}