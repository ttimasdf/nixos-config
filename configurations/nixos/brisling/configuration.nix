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
  # The leg itself — address, gateway, resolver and the routes back into the
  # zones edge-01 cannot reach on its own — is declared by the private module.
  systemd.network.enable = true;
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
