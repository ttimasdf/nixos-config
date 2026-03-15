{ config, lib, pkgs, ... }:

let
  cfg = config.services.ktransformers;
in
{
  options.services.ktransformers = {
    enable = lib.mkEnableOption "ktransformers inference service";
    package = lib.mkPackageOption pkgs "ktransformers" { };

    model = lib.mkOption {
      type = lib.types.path;
      description = "Path to model file (must be accessible to service user).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "HTTP API port.";
    };

    numa = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable NUMA optimizations.";
    };

    balanceServe = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable balanced serving mode for multi-GPU.";
    };

    gpus = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "0" ];
      description = "List of GPU devices to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.ktransformers = {
      description = "ktransformers inference service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        USE_NUMA = if cfg.numa then "1" else "0";
        USE_BALANCE_SERVE = if cfg.balanceServe then "1" else "0";
        CUDA_VISIBLE_DEVICES = builtins.concatStringsSep "," cfg.gpus;
      };

      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} --model ${cfg.model} --port ${toString cfg.port}";
        Restart = "on-failure";
        RestartSec = "30s";
        User = "ktransformers";
        Group = "ktransformers";
        StateDirectory = "ktransformers";
        WorkingDirectory = "/var/lib/ktransformers";
        LimitNOFILE = 65536;
      };
    };

    users.users.ktransformers = {
      isSystemUser = true;
      group = "ktransformers";
      extraGroups = [ "video" "render" ];
    };

    users.groups.ktransformers = { };
  };
}
