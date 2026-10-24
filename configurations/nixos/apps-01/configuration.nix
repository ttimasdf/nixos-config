# apps-01 — the application container host (unprivileged NixOS LXC, CT 137).
#
# Rootful Podman inside the LXC user namespace — the LXC userns is the security
# boundary (host uid 100000+), per the homelab overhaul decision.
#
# Networking:
#   eth0  6.6.90.105/16  — old LAN, transitional (internet + provisioning; dies at S6)
#   eth1  10.66.30.2/24  — servers zone; PVE tags VLAN 30 host-side (plain interface,
#                          no guest 802.1Q — CTs differ from VMs here). Gateway
#                          (edge-01, 10.66.30.1) activates at S3.
#
# Image: nh os build-image --image-variant proxmox-lxc .#apps-01
{ config, lib, pkgs, modulesPath, ... }:

{
  # The container IS the format — baked in (image attr + container boot bits for rebuilds)
  imports = [ "${modulesPath}/virtualisation/proxmox-lxc.nix" ];
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "apps-01";

  ### Networking
  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false;
  networking.enableIPv6 = false; # v4-only decision; the old-LAN GUA caused dead v6 egress
  networking.firewall.enable = true; # default-deny inbound, ssh allowed
  networking.interfaces.eth0.ipv4.addresses = [ { address = "6.6.90.105"; prefixLength = 16; } ];
  networking.defaultGateway = { address = "6.6.90.1"; interface = "eth0"; };
  networking.nameservers = [ "6.6.90.1" "223.5.5.5" ];
  networking.interfaces.eth1.ipv4.addresses = [ { address = "10.66.30.2"; prefixLength = 24; } ];

  ### Access — appliance: root + keys only
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDapIfzuMObd/aYexMBkHsB7cZl2mUSPEorAI9GbDaaa intra"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINyhqNCbETubhbUf8aSzR0+6bZYkSpEo7Ri1WIuPdiyR nix-builder"
  ];

  ### Podman — rootful; graphroot pinned on the /data mount point (PVE mp0)
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";
  virtualisation.containers.storage.settings = {
    storage.driver = "overlay";
    storage.graphroot = "/data/containers/storage";
    storage.runroot = "/run/containers/storage";
  };

  ### Registry egress via mihomo (viscacha pattern): pulls through the CT-114 proxy
  rabit.nixos.http_proxy = "http://6.6.6.1:28888";
  rabit.nixos.no_proxy = "localhost,127.0.0.1,[::1],6.6.0.0/16,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12";
  systemd.services."podman".environment = {
    http_proxy = config.rabit.nixos.http_proxy;
    https_proxy = config.rabit.nixos.http_proxy;
    no_proxy = config.rabit.nixos.no_proxy;
  };
  systemd.user.services."podman".environment = {
    http_proxy = config.rabit.nixos.http_proxy;
    https_proxy = config.rabit.nixos.http_proxy;
    no_proxy = config.rabit.nixos.no_proxy;
  };
  environment.etc."profile.d/podman-proxy.sh".text = ''
    export http_proxy=http://6.6.6.1:28888
    export https_proxy=http://6.6.6.1:28888
    export no_proxy=localhost,127.0.0.1,6.6.0.0/16,10.0.0.0/8
  '';

  ### Services land here as they migrate (fresh Forgejo first, per the plan).

  system.stateVersion = "26.11";
}
