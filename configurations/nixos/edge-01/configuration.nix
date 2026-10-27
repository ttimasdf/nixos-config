# edge-01 — the zone-fabric VM (homelab overhaul, S1).
#
# Single trunk NIC (untagged on the PVE vlan-aware bridge):
#   eth0      untagged = old LAN (transitional provisioning/mgmt; dies at S6)
#   eth0.50   10.66.50.2/24  — uplink zone (gw 10.66.50.1 on OpenWrt)
#   eth0.20   10.66.20.1/24  — soc zone gateway (empty for now)
#   eth0.30   10.66.30.1/24  — servers zone gateway (tag-path test target)
#   eth0.90   10.66.90.1/24  — sandbox zone gateway (empty for now)
#   eth0.10   10.66.10.1/24   — mgmt zone gateway, edge owns .1 from day 1
#             (the router's transitional leg uses 10.66.10.254)
#
# Roles OFF in S1: no ip_forward, no zone firewall, no DHCP/DNS, no EasyTier.
# Activated in S3 with physical presence.
{ flake, pkgs, lib, modulesPath, ... }:

{
  ### Image: built via `nh os build-image --image-variant proxmox .#edge-01`
  ### (upstream image registry; no format module baked into the host config)
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "edge-01"; # was missing — VM leased as "nixos"
  boot.growPartition = true;
  services.qemuGuest.enable = true;

  ### Boot — EFI per fleet policy (progress/2026-10-25-boot-policy.md):
  ### OVMF + persistent efidisk0 (PVE-side) + systemd-boot; grub retired.
  ### Image layout: ESP-first (1G via the private image entry), root-last/growable.
  boot.loader.grub.enable = false; # override the proxmox image profile's default
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5; # 1G ESP, edge kernel+initrd ~30M/gen
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200n8" ]; # qm terminal

  ### Networking — one trunk NIC, predictable names off => eth0
  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false;
  networking.firewall.enable = true; # default-deny inbound, ssh allowed
  networking.interfaces.eth0.useDHCP = true; # old-LAN provisioning (transitional)

  networking.vlans = {
    vlan10 = {
      id = 10;
      interface = "eth0";
    };
    vlan20 = {
      id = 20;
      interface = "eth0";
    };
    vlan30 = {
      id = 30;
      interface = "eth0";
    };
    vlan50 = {
      id = 50;
      interface = "eth0";
    };
    vlan90 = {
      id = 90;
      interface = "eth0";
    };
  };

  networking.interfaces = {
    vlan10.ipv4.addresses = [ { address = "10.66.10.1"; prefixLength = 24; } ];
    vlan20.ipv4.addresses = [ { address = "10.66.20.1"; prefixLength = 24; } ];
    vlan30.ipv4.addresses = [ { address = "10.66.30.1"; prefixLength = 24; } ];
    vlan50.ipv4.addresses = [ { address = "10.66.50.2"; prefixLength = 24; } ];
    vlan90.ipv4.addresses = [ { address = "10.66.90.1"; prefixLength = 24; } ];
  };
  # No default route via vlan50 yet (eth0 DHCP provides one via the old LAN).
  # IPv6: none on the new zones (decision) — no v6 addrs anywhere.

  ### Access — appliance: root + keys only, no interactive users
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDapIfzuMObd/aYexMBkHsB7cZl2mUSPEorAI9GbDaaa intra"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINyhqNCbETubhbUf8aSzR0+6bZYkSpEo7Ri1WIuPdiyR nix-builder"
  ];

  imports = [ ./services.nix ]; # Technitium, Caddy, EasyTier peer, dnsmasq, mihomo land there

  system.stateVersion = "26.11";
}
