{ config, lib, pkgs, ... }:

let
  cfg = config.programs.fido-linux-id;
in
{
  options.programs.fido-linux-id = {
    enable = lib.mkEnableOption "fido-linux-id";
    package = lib.mkPackageOption pkgs "fido-linux-id" { };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    users.groups.uhid = { };

    # https://aur.archlinux.org/cgit/aur.git/tree/99-tpm-fido.rules?h=tpm-fido-git
    services.udev.packages = lib.mkIf cfg.enable [
      (pkgs.writeTextDir "etc/udev/rules.d/55-uhid.rules" ''
        KERNEL=="uhid", SUBSYSTEM=="misc", GROUP="uhid", MODE="0660"
      '')
    ];

    systemd.user.services.fido-linux-id = {
      description = cfg.package.meta.description;
      # wantedBy = [ "graphical-session.target" ];
      wantedBy = [ "default.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe cfg.package}";
        StandardOutput = "journal";
      };
    };

  };
}
