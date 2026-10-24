# edge-01 — the zone-fabric VM (homelab overhaul, S1).
#
# Single trunk NIC (untagged on the PVE vlan-aware bridge):
#   eth0      untagged = old LAN (transitional provisioning/mgmt; dies at S6)
#   eth0.50   10.66.50.2/24  — uplink zone (gw 10.66.50.1 on OpenWrt)
#   eth0.20   10.66.20.1/24  — soc zone gateway (empty for now)
#   eth0.30   10.66.30.1/24  — servers zone gateway (tag-path test target)
#   eth0.90   10.66.90.1/24  — sandbox zone gateway (empty for now)
#   eth0.10   ADDRESSLESS during S1 — the router holds 10.66.10.1 transitionally;
#             edge-01 takes it at S3 (see homelab-overhaul/progress/WORKING.md).
#
# Roles OFF in S1: no ip_forward, no zone firewall, no DHCP/DNS, no EasyTier.
# Activated in S3 with physical presence.
{ flake, pkgs, lib, modulesPath, ... }:

{
  ### VM basics — the proxmox format module provides fileSystems + bootloader
  ### (equivalent to `nixos-generate -f proxmox`, without the external tool)
  imports = [ "${modulesPath}/virtualisation/proxmox-image.nix" ];
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.growPartition = true;
  services.qemuGuest.enable = true;

  ### Networking — one trunk NIC, predictable names off => eth0
  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false;
  networking.firewall.enable = true; # default-deny inbound, ssh allowed
  networking.interfaces.eth0.useDHCP = true; # old-LAN provisioning (transitional)

  networking.vlans = {
    vlan10 = {
      id = 10;
      interface = "eth0";
    }; # addressless until S3 (router holds 10.66.10.1)
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

  ### S3 will bring: nftables zone policy, DHCP-only dnsmasq, Technitium,
  ### Caddy + wildcard cert, EasyTier peer, mihomo listener. One rebuild away.

  system.stateVersion = "26.11";
}
