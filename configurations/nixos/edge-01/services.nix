# edge-01 services — the services file.
#
# Landed:
#   - Technitium DNS (authoritative lab.domain.invalid + recursor; split-horizon with Spaceship)
#   - security.acme wildcard *.lab.domain.invalid (DNS-01 via Spaceship API; CT logs see only
#     the wildcard — individual service names never appear)
#
# Planned (see homelab-overhaul/progress/WORKING.md):
#   - Caddy reverse proxy (consumes the wildcard via useACMEHost)
#   - EasyTier peer (10.66.40.0/24 mesh, new network name/password)
#   - dnsmasq DHCP-only for the zones (port=0; Technitium owns :53)
#   - mihomo listener-only (egress chain endpoint for sandbox-01)
{ config, pkgs, ... }:

{
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
    certs."lab.domain.invalid" = {
      domain = "lab.domain.invalid";
      extraDomainNames = [ "*.lab.domain.invalid" ];
      dnsProvider = "spaceship";
      environmentFile = "/var/lib/secrets/spaceship.env"; # delivered out-of-band, 0600 root
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
    vlan90.allowedTCPPorts = [ 53 ];
    vlan90.allowedUDPPorts = [ 53 ];
    eth0.allowedTCPPorts = [ 5380 ]; # transitional console access from old LAN
  };
}
