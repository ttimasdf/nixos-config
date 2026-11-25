# edge-01 services: DNS, certificate, per-leg firewall.
#
# The legs, their addresses and the per-leg INPUT policy are private; this file
# only enables services and names the one intra-network value that is public by
# design — the domain the wildcard certificate is issued for.
{ config, ... }:

let
  inherit (config.rabitprivate.nixos.homelab) domain;
  noProxy = "localhost,127.0.0.1,[::1],10.0.0.0/8,192.168.0.0/16,172.16.0.0/12";
in
{
  rabit.nixos.no_proxy = noProxy;

  # Never a side effect of another service (netavark used to set it).
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  services.technitium-dns-server = {
    enable = true;
    openFirewall = false; # per-leg rules below govern
  };
  # DynamicUser relocates the state dir to /var/lib/private/<name>; binding the
  # public path fails the StateDirectory migration with EBUSY.
  fileSystems."/var/lib/private/technitium-dns-server" = {
    device = "/srv/technitium";
    fsType = "none";
    options = [ "bind" ];
  };
  fileSystems."/var/lib/acme" = {
    device = "/srv/acme";
    fsType = "none";
    options = [ "bind" ];
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "cortex-red@rabit.pw";
    certs."${domain}" = {
      domain = domain;
      extraDomainNames = [ "*.${domain}" ];
      dnsProvider = "spaceship";
      environmentFile = "/run/secrets/rendered/spaceship.env";
      # The system resolver negative-caches NXDOMAIN until the registrar's
      # authoritative NS has the record; poll that NS instead.
      dnsResolver = "162.159.26.38:53";
    };
  };
}
