{ flake, config, lib, ... }:
{
  options = {
    rabit.nixos = {
      http_proxy = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "http://127.0.0.1:28888";
        description = "Proxy URL for outgoing HTTP requests";
      };
      no_proxy = lib.mkOption {
        type = lib.types.str;
        default = "localhost,127.0.0.1,192.168.0.0/16,172.0.0.0/12,10.0.0.0/8,6.6.0.0/16";
        example = "localhost,127.0.0.1,192.168.0.0/16,172.0.0.0/12,10.0.0.0/8";
        description = "Proxy URL for outgoing HTTP requests";
      };
    };
  };
}