{ config, lib, pkgs, ... }:

let
  cfg = config.programs.fido-linux-id;
in
{
  options.programs.fido-linux-id = {
    enable = lib.mkEnableOption "fido-linux-id";
    package = lib.mkPackageOption pkgs "fido-linux-id" { };
    pinentryPackage = lib.mkPackageOption pkgs "pinentry-qt" { };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package cfg.pinentryPackage ];
    users.groups.uhid = { };

    # https://aur.archlinux.org/cgit/aur.git/tree/99-tpm-fido.rules?h=tpm-fido-git
    services.udev.packages = lib.mkIf cfg.enable [
      (pkgs.writeTextDir "etc/udev/rules.d/55-uhid.rules" ''
        KERNEL=="uhid", SUBSYSTEM=="misc", GROUP="uhid", MODE="0660", TAG+="uaccess"
      '')
    ];

    systemd.user.services.fido-linux-id = {
      description = cfg.package.meta.description;
      wantedBy = [ "graphical-session.target" ];
      # wantedBy = [ "default.target" ];

      path = [ cfg.pinentryPackage ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe cfg.package}";
        StandardOutput = "journal";
      };
    };

  };
}
