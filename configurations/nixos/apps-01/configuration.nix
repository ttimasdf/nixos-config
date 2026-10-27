# apps-01 — the application container host (unprivileged NixOS LXC, CT 137).
#
# Rootful Podman inside the LXC user namespace — the LXC userns is the security
# boundary (host uid 100000+), per the homelab overhaul decision.
#
# Networking:
#   eth0  10.66.30.2/24  — servers zone PRIMARY (PVE net0 tag=30). Default gw
#                          edge-01 (10.66.30.1) — FLEET CONVENTION: net0 = new zone.
#   eth1  6.6.90.105/16  — old LAN backup, no gateway (dies at S6)
#
# Image: nh os build-image --image-variant proxmox-lxc .#apps-01
{ config, lib, pkgs, modulesPath, ... }:

{
  # The container IS the format — baked in (image attr + container boot bits for rebuilds)
  imports = [ "${modulesPath}/virtualisation/proxmox-lxc.nix" ];
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "apps-01";
  proxmoxLXC.manageHostName = true; # eval must see the real hostname — mkIf-hostname private modules key on it (the module's mkForce "" silently skipped them all)

  ### Networking
  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false;
  networking.enableIPv6 = false; # v4-only decision; the old-LAN GUA caused dead v6 egress
  networking.firewall.enable = true; # default-deny inbound, ssh allowed
  networking.interfaces.eth0.ipv4.addresses = [ { address = "10.66.30.2"; prefixLength = 24; } ];
  networking.defaultGateway = { address = "10.66.30.1"; interface = "eth0"; };
  networking.nameservers = [ "10.66.10.1" "6.6.90.1" ];
  networking.interfaces.eth1.ipv4.addresses = [ { address = "6.6.90.105"; prefixLength = 16; } ];

  ### Access — appliance: root + keys only
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDapIfzuMObd/aYexMBkHsB7cZl2mUSPEorAI9GbDaaa intra"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINyhqNCbETubhbUf8aSzR0+6bZYkSpEo7Ri1WIuPdiyR nix-builder"
  ];

  ### Podman — rootful; storage on the /srv data volume (PVE mp0) via a bind
  ### into podman's DEFAULT path — no graphroot override needed (fleet /srv
  ### convention, 2026-10-26)
  fileSystems."/var/lib/containers" = {
    device = "/srv/containers";
    fsType = "none";
    options = [ "bind" ];
  };

  ### EasyTier control plane — web console + config server.
  ### Internal peers use direct UDP (port via private module); roaming peers use
  ### the frp-exposed endpoint. All frp/mesh addressing lives in the private
  ### module — relay server addresses are confidential (operator rule 2026-10-27).
  users.users.easytier = { isSystemUser = true; group = "easytier"; };
  users.groups.easytier = { };
  systemd.tmpfiles.rules = [ "d /srv/easytier-web 0700 easytier easytier -" ];
  systemd.services.easytier-web = {
    description = "EasyTier web console + config server";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "easytier";
      Group = "easytier";
      WorkingDirectory = "/srv/easytier-web";
      ExecStart = "${pkgs.easytier-bin}/bin/easytier-web-embed --db /srv/easytier-web/et.db --api-server-addr 0.0.0.0 --api-server-port 11211 --config-server-protocol udp --config-server-port 22020";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
  networking.firewall.allowedTCPPorts = [ 11211 ]; # console/API, internal (vlan30 ingress)
  networking.firewall.allowedUDPPorts = [ 22020 ]; # config server, internal peers
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

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
