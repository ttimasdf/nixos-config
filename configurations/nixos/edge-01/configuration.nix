# edge-01 — inter-zone router: one trunk NIC, one VLAN per zone.
#
# The trunk itself — VLAN ids, link names, zone addresses, transit routes, NAT
# and the per-leg firewall — is declared by the private module, which owns the
# intra-network identity. Nothing here names a zone or carries an address.
{ ... }:

{
  imports = [ ./services.nix ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "edge-01";
  boot.growPartition = true;
  services.qemuGuest.enable = true;

  boot.loader.grub.enable = false; # the proxmox image profile enables it
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5; # 1 GiB ESP holds kernel+initrd
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200n8" ];

  networking.usePredictableInterfaceNames = false;
  networking.useNetworkd = true;
  networking.useDHCP = false;
  networking.firewall.enable = true;
  # cloud-init's 10-cloud-init-eth0.network sorts before the generated
  # 40-eth0.network and wins the match, which drops every VLAN attachment.
  services.cloud-init.network.enable = false;

  networking.nameservers = [ "223.5.5.5" "223.6.6.6" ];

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDapIfzuMObd/aYexMBkHsB7cZl2mUSPEorAI9GbDaaa intra"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINyhqNCbETubhbUf8aSzR0+6bZYkSpEo7Ri1WIuPdiyR nix-builder"
  ];

  system.stateVersion = "26.11";
}
