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
        default = null;
        example = "http://127.0.0.1:28888";
        description = "the URL of the intermediary server used for routing outbound HTTP traffic";
      };
      no_proxy = lib.mkOption {
        type = lib.types.str;
        default = "localhost,127.0.0.1,[::1],192.168.0.0/16,172.0.0.0/12,10.0.0.0/8";
        description = "a comma-separated list of domains and IP addresses that should bypass this proxy and be accessed directly";
      };
      myusers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "List of usernames";
        example = lib.attrNames homePaths;
      };
    };
  };
}