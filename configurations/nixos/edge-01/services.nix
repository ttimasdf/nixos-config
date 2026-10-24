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

  ### Technitium DNS — persistent state on /data (separate zvol = backup unit)
  virtualisation.oci-containers.containers.technitium = {
    image = "docker.io/technitiumdns/dns-server:12.2";
    autoStart = true;
    ports = [
      # DNS on each zone address (zone clients point at their gateway)
      "10.66.10.1:53:53/udp" "10.66.10.1:53:53/tcp"
      "10.66.20.1:53:53/udp" "10.66.20.1:53:53/tcp"
      "10.66.30.1:53:53/udp" "10.66.30.1:53:53/tcp"
      "10.66.90.1:53:53/udp" "10.66.90.1:53:53/tcp"
      # web console: transitional access via the old LAN address
      "6.6.90.13:5380:5380/tcp"
    ];
    volumes = [ "/data/technitium:/etc/dns" ];
  };

  ### Wildcard cert — one cert, all services; subdomains never hit CT logs
  security.acme = {
    acceptTerms = true;
    defaults.email = "cortex-red@rabit.pw";
    certs."${labDomain}" = {
      domain = labDomain;
      extraDomainNames = [ "*.${labDomain}" ];
      dnsProvider = "spaceship";
      environmentFile = "/var/lib/secrets/spaceship.env"; # delivered out-of-band, 0600 root
      # Poll the registrar's authoritative NS for propagation — the system
      # resolver (ISP) negative-caches NXDOMAIN and fails the default check.
      dnsResolver = "162.159.26.38:53"; # launch1.spaceship.net
    };
  };

  ### The container unit needs the proxy env itself (pre-start pulls don't
  ### inherit podman.service env, and profile.d doesn't reach systemd units)
  systemd.services.podman-technitium.environment = {
    http_proxy = config.rabit.nixos.http_proxy;
    https_proxy = config.rabit.nixos.http_proxy;
    no_proxy = config.rabit.nixos.no_proxy;
  };

  ### Firewall: allow DNS + console from the zones (ssh already allowed by default policy)
  networking.firewall.interfaces = {
    vlan10.allowedTCPPorts = [ 53 5380 ];
    vlan10.allowedUDPPorts = [ 53 ];
    vlan20.allowedTCPPorts = [ 53 ];
    vlan20.allowedUDPPorts = [ 53 ];
    vlan30.allowedTCPPorts = [ 53 ];
    vlan30.allowedUDPPorts = [ 53 ];
    vlan90.allowedTCPPorts = [ 53 ];
    vlan90.allowedUDPPorts = [ 53 ];
    eth0.allowedTCPPorts = [ 5380 ]; # transitional console access from old LAN
  };
}
