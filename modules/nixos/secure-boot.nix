{ pkgs, lib, ... }:
{
  # Shared Limine Secure Boot policy. Keys already in /var/lib/sbctl are
  # reused; a machine without them gets keys generated and enrolled during
  # bootloader installation, so the firmware must be in Setup Mode first.
  boot.loader.limine = {
    enable = true;
    enableEditor = false;
    secureBoot = {
      enable = true;
      autoGenerateKeys = true;
      autoEnrollKeys.enable = true;
    };
  };

  # Limine is the bootloader backend for hosts importing this module.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [ sbctl ];
}
