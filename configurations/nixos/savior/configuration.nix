{ flake, config, lib, pkgs, ... }:

let
  inherit (flake.inputs) self;
in
{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # https://wiki.nixos.org/wiki/Serial_Console

  # Enable early console output during boot
  boot.consoleLogLevel = 7;  # Show all kernel messages
  boot.initrd.verbose = true;  # Show initrd messages

  boot.kernelParams = [ "console=ttyS0,115200n8" ];
  # boot.loader.grub.extraConfig is *NOT* applied to ISO image.
  # see <nixpkgs>/nixos/modules/installer/cd-dvd/iso-image.nix

  services.getty.autologinUser = lib.elemAt config.rabit.nixos.myusers 0;

  systemd.services.sshd.wantedBy = lib.mkForce ["multi-user.target"];

  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
    # system monitoring tools
    htop
    btop

    # hardware info
    inxi
    lm_sensors
    pciutils

    # file utilities
    ncdu
    _7zz-natspec
    compsize
    ripgrep
    wormhole-cli
  ];
}