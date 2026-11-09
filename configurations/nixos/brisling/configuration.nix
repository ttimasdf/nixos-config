{
  flake,
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  inherit (flake.inputs) self;
  inherit (config.rabitprivate.nixos.homelab) ipv4;
  cidr = name: "${ipv4.networks.${name}}/${toString ipv4.prefixLength}";
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # config options only applied to proxmox LXC image.
  image.modules.proxmox-lxc = {
    imports = [
      # "${modulesPath}/profiles/bashless.nix"
      "${modulesPath}/profiles/image-based-appliance.nix"
    ];

    services.getty.autologinUser = "nixos";
    security.sudo.extraRules = [{
      groups = [ "wheel" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }];
  };

  # region user settings
  rabit.nixos.myusers = [ "nixos" ];
  time.timeZone = "Asia/Shanghai";
  # endregion user settings

  # region network
  networking.hostName = "brisling";
  networking.useNetworkd = true;
  boot.isContainer = true; # bare eval needs it (the image path also sets it)
  services.openssh.enable = true; # sops-nix derives the age key from the ssh host key
  networking.useHostResolvConf = false;
  # Rescue box: route only the zones the router cannot reach, so the rest stay
  # reachable through the router when edge-01 is down.
  systemd.network = {
    enable = true;
    networks."10-eth0" = {
      matchConfig.Name = "eth0";
      address = [ "${ipv4.addresses.brisling}/${toString ipv4.prefixLength}" ];
      gateway = [ ipv4.addresses.router-mgmt ];
      dns = [ ipv4.zones.mgmt.address "223.5.5.5" ];
      routes = map (name: { Destination = cidr name; Gateway = ipv4.zones.mgmt.address; }) [ "soc" "servers" "sandbox" ];
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = false;
      };
    };
  };
  # endregion network

  # region software
  # programs.vim.enable = true;
  # programs.vim.defaultEditor = true;

  # services.openssh = {
  #   enable = true;
  #   openFirewall = true;
  #   settings = {
  #     PasswordAuthentication = false;
  #     KbdInteractiveAuthentication = false;
  #     PermitRootLogin = "prohibit-password";
  #   };
  # };
  # endregion software

  # region nix config
  system.stateVersion = "25.05";
  # endregion nix config
}
