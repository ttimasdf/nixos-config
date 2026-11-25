# apps-01 — application container host (unprivileged NixOS LXC).
#
# Rootful Podman inside the LXC user namespace: the userns is the security
# boundary, so container root cannot reach host root.
{ pkgs, modulesPath, ... }:

{
  imports = [ "${modulesPath}/virtualisation/proxmox-lxc.nix" ];
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "apps-01";
  # mkForce of "" would make every mkIf-hostname private module a silent no-op.
  proxmoxLXC.manageHostName = true;

  networking.usePredictableInterfaceNames = false;
  networking.useNetworkd = true;
  networking.useDHCP = false;
  networking.enableIPv6 = false;
  networking.firewall.enable = true; # default deny, ssh allowed
  # Address, gateway, resolver and the registry proxy are applied by the
  # private module; this file names none of them.
  rabit.nixos.no_proxy = "localhost,127.0.0.1,[::1],10.0.0.0/8,192.168.0.0/16,172.16.0.0/12";

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDapIfzuMObd/aYexMBkHsB7cZl2mUSPEorAI9GbDaaa intra"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINyhqNCbETubhbUf8aSzR0+6bZYkSpEo7Ri1WIuPdiyR nix-builder"
  ];

  # Data volume at /srv, bound onto podman's default path (no graphroot override).
  fileSystems."/var/lib/containers" = {
    device = "/srv/containers";
    fsType = "none";
    options = [ "bind" ];
  };

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
  networking.firewall.allowedTCPPorts = [ 11211 ]; # console/API
  networking.firewall.allowedUDPPorts = [ 22020 ]; # config server
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  system.stateVersion = "26.11";
}
