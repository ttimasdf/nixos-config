# edge-01 — inter-zone router: one trunk NIC, one VLAN per zone.
{ config, lib, ... }:

let
  inherit (config.rabitprivate.nixos.homelab) ipv4;
  # Zones addressed here; the rest are router-owned and only routed.
  ownZones = lib.filterAttrs (_: zone: zone.address != null) ipv4.zones;
  link = name: ipv4.zones.${name}.link;
  wired = map link [ "mgmt" "soc" "servers" "sandbox" ];
  wiredSet = lib.concatStringsSep " " (map (iface: ''"${iface}"'') wired);
in
{
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "edge-01";
  boot.growPartition = true;
  services.qemuGuest.enable = true;

  boot.loader.grub.enable = false; # the proxmox image profile enables it
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5; # 1 GiB ESP holds kernel+initrd
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200n8" ];

  networking.usePredictableInterfaceNames = false;
  networking.useNetworkd = true;
  networking.useDHCP = false;
  networking.firewall.enable = true;
  # cloud-init's 10-cloud-init-eth0.network sorts before the generated
  # 40-eth0.network and wins the match, which drops every VLAN attachment.
  services.cloud-init.network.enable = false;

  networking.vlans = lib.mapAttrs' (name: zone: lib.nameValuePair zone.link {
    id = zone.id;
    interface = "eth0";
  }) ownZones;
  networking.interfaces = lib.recursiveUpdate
    (lib.mapAttrs' (name: zone: lib.nameValuePair zone.link {
      ipv4.addresses = [ { address = zone.address; prefixLength = ipv4.prefixLength; } ];
    }) ownZones)
    {
      eth0.useDHCP = true;
      # Router-owned zones are reached over the transit link, never on-link: a
      # second L3 device in someone else's zone re-creates connected-route asymmetry.
      ${link "transit"}.ipv4.routes = map (name: {
        address = ipv4.networks.${name};
        prefixLength = ipv4.prefixLength;
        via = ipv4.addresses.router-transit;
      }) [ "clients" "iot" "guest" ];
    };

  networking.nat = {
    enable = true;
    externalInterface = "eth0";
    internalInterfaces = wired;
  };
  networking.firewall.extraForwardRules = ''
    iifname "${link "soc"}" oifname "${link "mgmt"}" counter drop
    iifname { ${wiredSet} } oifname "eth0" counter accept
    iifname "tun40" oifname { ${wiredSet} } counter accept
    iifname { ${wiredSet} } oifname { ${wiredSet} } counter accept
  '';
  networking.nameservers = [ "223.5.5.5" "223.6.6.6" ];

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDapIfzuMObd/aYexMBkHsB7cZl2mUSPEorAI9GbDaaa intra"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINyhqNCbETubhbUf8aSzR0+6bZYkSpEo7Ri1WIuPdiyR nix-builder"
  ];

  system.stateVersion = "26.11";
}
