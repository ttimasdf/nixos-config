{ config, lib, pkgs, ... }:

let
  cfg = config.programs.astral;
in
{
  options.programs.astral = {
    enable = lib.mkEnableOption "astral";
    package = lib.mkPackageOption pkgs "astral-ng" { };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    security.wrappers.astral = {
      owner = "root";
      group = "root";
      capabilities = "cap_net_admin+ep";
      source = lib.getExe cfg.package;
    };
  };
}
