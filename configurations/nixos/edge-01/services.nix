# edge-01 services — the services file.
#
# Landed:
#   - Technitium DNS (authoritative zone for the lab domain + recursor;
#     split-horizon with the registrar's public zone)
#   - security.acme wildcard cert (DNS-01 via the registrar's API; CT logs see
#     only the wildcard — individual service names never appear)
#
# The domain itself is a secret: rabitprivate.nixos.labDomain (private repo).
#
# Planned (see homelab-overhaul/progress/WORKING.md):
#   - Caddy reverse proxy (consumes the wildcard via useACMEHost)
#   - EasyTier peer (10.66.40.0/24 mesh, new network name/password)
#   - dnsmasq DHCP-only for the zones (port=0; Technitium owns :53)
#   - mihomo listener-only (egress chain endpoint for sandbox-01)
{ config, pkgs, ... }:

let
  labDomain = config.rabitprivate.nixos.labDomain;
in
{
  ### Podman egress via mihomo (registry pulls), same pattern as apps-01
  rabit.nixos.http_proxy = "http://6.6.6.1:28888";
  rabit.nixos.no_proxy = "localhost,127.0.0.1,[::1],6.6.0.0/16,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12";
  systemd.services."podman".environment = {
    http_proxy = config.rabit.nixos.http_proxy;
    https_proxy = config.rabit.nixos.http_proxy;
    no_proxy = config.rabit.nixos.no_proxy;
  };
  environment.etc."profile.d/podman-proxy.sh".text = ''
    export http_proxy=http://6.6.6.1:28888
    export https_proxy=http://6.6.6.1:28888
    export no_proxy=localhost,127.0.0.1,6.6.0.0/16,10.0.0.0/8
  '';

  ### Routing — edge is the inter-zone router (transitional: SNAT paths via
  ### vlan10 ↔ other zones; S3 brings the nftables zone policy). Previously
  ### ip_forward=1 was set as a SIDE EFFECT of netavark (container published
  ### ports) — removing the Technitium container silently disabled routing.
  ### Declared explicitly since 2026-10-26.
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  ### Technitium DNS — NATIVE nixpkgs module (was pinned container; migrated
  ### 2026-10-26). State lives on the /srv volume, bind-mounted into the
  ### module's StateDirectory. No dnsmasq anywhere — Technitium's built-in
  ### DHCP serves the zones at S3 (operator decision).
  services.technitium-dns-server = {
    enable = true;
    openFirewall = false; # per-interface rules below remain the governing layer
  };
  # DynamicUser service — state lives under /var/lib/private/<name> (systemd
  # relocates the public path there); the bind must target the PRIVATE path or
  # the StateDirectory migration fails with EBUSY (learned 2026-10-26).
  fileSystems."/var/lib/private/technitium-dns-server" = {
    device = "/srv/technitium";
    fsType = "none";
    options = [ "bind" ];
  };

  ### ACME certs centralized on /srv too (same convention)
  fileSystems."/var/lib/acme" = {
    device = "/srv/acme";
    fsType = "none";
    options = [ "bind" ];
  };

  ### Wildcard cert — one cert, all services; subdomains never hit CT logs
  security.acme = {
    acceptTerms = true;
    defaults.email = "cortex-red@rabit.pw";
    certs."${labDomain}" = {
      domain = labDomain;
      extraDomainNames = [ "*.${labDomain}" ];
      dnsProvider = "spaceship";
      environmentFile = "/run/secrets/rendered/spaceship.env"; # sops template from per-key YAML secrets (private edge-01 module)
      # Poll the registrar's authoritative NS for propagation — the system
      # resolver (ISP) negative-caches NXDOMAIN and fails the default check.
      dnsResolver = "162.159.26.38:53"; # launch1.spaceship.net
    };
  };

  ### Firewall: allow DNS + console from the zones (ssh already allowed by default policy)
  networking.firewall.interfaces = {
    vlan10.allowedTCPPorts = [ 53 5380 ];
    vlan10.allowedUDPPorts = [ 53 ];
    vlan20.allowedTCPPorts = [ 53 ];
    vlan20.allowedUDPPorts = [ 53 ];
    vlan30.allowedTCPPorts = [ 53 ];
    vlan30.allowedUDPPorts = [ 53 ];
    vlan50.allowedTCPPorts = [ 22 53 5380 ]; # routed mgmt path from old LAN via router↔vlan50 trunk (S3 cutover; was masked by SNAT before)
    vlan50.allowedUDPPorts = [ 53 ];
    vlan90.allowedTCPPorts = [ 53 ];
    vlan90.allowedUDPPorts = [ 53 ];
    eth0.allowedTCPPorts = [ 5380 ]; # transitional console access from old LAN
  };
}
