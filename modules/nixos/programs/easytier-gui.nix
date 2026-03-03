{ config, lib, pkgs, ... }:

let
  cfg = config.programs.easytier-gui;
in
{
  options.programs.easytier-gui = {
    enable = lib.mkEnableOption "easytier-gui";
    package = lib.mkPackageOption pkgs "easytier-gui" { };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    security.wrappers.easytier-gui = {
      owner = "root";
      group = "root";
      capabilities = "cap_net_admin+ep";
      source = lib.getExe cfg.package;
    };
  };
}
