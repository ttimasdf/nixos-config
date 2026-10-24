# edge-01 hardware (VM 140): matches the `proxmox` image variant layout —
# single virtio disk, BIOS grub, root by label. No ESP (no /boot mount).
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" "virtio_blk"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-label/EDGE-DATA";
    fsType = "ext4";
  };

  swapDevices = [ ];

  boot.loader.grub.devices = [ "/dev/vda" ];
}
