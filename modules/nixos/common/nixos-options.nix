{ flake, config, lib, ... }:
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
        default = "localhost,127.0.0.1,[::1],192.168.0.0/16,172.0.0.0/12,10.0.0.0/8,6.6.0.0/16";
        example = "localhost,127.0.0.1,[::1],192.168.0.0/16,172.0.0.0/12,10.0.0.0/8";
        description = "a comma-separated list of domains and IP addresses that should bypass this proxy and be accessed directly";
      };
      # rabit.nixos.myusers option is defined in modules/nixos/common/myusers.nix
    };
  };
}