{ pkgs, lib, ... }:
{
  # Shared Limine Secure Boot policy. Existing keys in /var/lib/sbctl are
  # intentionally reused; key generation and firmware enrollment are left to
  # explicit administrative actions.
  boot.loader.limine = {
    enable = true;
    enableEditor = false;
    secureBoot = {
      enable = true;
      autoGenerateKeys = false;
      autoEnrollKeys.enable = false;
    };
  };

  # Limine is the bootloader backend for hosts importing this module.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [ sbctl ];
}
