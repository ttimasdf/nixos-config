# edge-01 services: DNS, certificate, per-leg firewall.
{ config, ... }:

let
  inherit (config.rabitprivate.nixos.homelab) domain ipv4;
  link = name: ipv4.zones.${name}.link;
  proxyUrl = "http://${ipv4.addresses.proxy}:28888";
  noProxy = "localhost,127.0.0.1,[::1],10.0.0.0/8,192.168.0.0/16,172.16.0.0/12";
in
{
  rabit.nixos.http_proxy = proxyUrl;
  rabit.nixos.no_proxy = noProxy;
  systemd.services."podman".environment = {
    http_proxy = proxyUrl;
    https_proxy = proxyUrl;
    no_proxy = noProxy;
  };
  environment.etc."profile.d/podman-proxy.sh".text = ''
    export http_proxy=${proxyUrl}
    export https_proxy=${proxyUrl}
    export no_proxy=localhost,127.0.0.1,10.0.0.0/8
  '';

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

  networking.firewall.interfaces = {
    ${link "mgmt"} = {
      allowedTCPPorts = [ 22 53 5380 ];
      allowedUDPPorts = [ 53 ];
    };
    ${link "soc"} = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };
    ${link "servers"} = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 67 ]; # 67 = DHCP scope for this zone
    };
    ${link "sandbox"} = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };
  };
}
