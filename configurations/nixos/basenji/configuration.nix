# NAS virtual machine configuration with Cockpit for remote management
{
  flake,
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (flake.inputs) self;
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # region boot & kernel
  boot.loader = {
    grub = {
      efiSupport = true;
      device = "/dev/disk/by-diskseq/1";
    };
  };
  boot.kernelPackages = pkgs.linuxPackages;
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  # ZFS support for the raid-z pool "bank"
  boot.supportedFilesystems.zfs = true;
  # ZFS requires networking.hostId to be set
  networking.hostId = "a8c4e2f1";

  # endregion boot & kernel

  # region user settings
  rabit.nixos.myusers = [ "nas" ];
  # endregion user settings

  # region network
  networking.hostName = "basenji";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Shanghai";

  # endregion network

  # region ZFS pool configuration
  # The "bank" pool will be configured via hardware-configuration.nix
  # or manually imported with: zpool import bank
  services.zfs.autoScrub.enable = true;
  services.zfs.autoScrub.pools = [ "bank" ];
  services.zfs.trim.enable = true;
  # endregion ZFS pool configuration

  # region Cockpit web management
  # Cockpit provides a web-based interface for system administration.
  # Note: Many plugins are built into cockpit or provided via cockpit-zfs.
  # For podman management, install cockpit-podman on the system (if available)
  # or use the built-in terminal/session features.
  services.cockpit = {
    enable = true;
    port = 9090;
    openFirewall = true;
    allowed-origins = [ "*" ];
    settings = {
      WebService = {
        ProtocolHeader = "X-Forwarded-Proto";
        ForwardedForHeader = "X-Forwarded-For";
      };
    };
  };

  # endregion Cockpit web management

  # region Samba file sharing
  # Ensure samba starts after the ZFS pool /bank is mounted
  systemd.services.samba-smbd.requires = [ "bank.mount" ];
  systemd.services.samba-smbd.after = [ "bank.mount" ];

  services.samba = {
    enable = true;
    openFirewall = true;
    settings =
      let
        commonConfig = {
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = "nas";
          "force group" = "users";
        };
      in
      {
        global = {
          workgroup = "WORKGROUP";
          "server string" = "basenji NAS";
          "server role" = "standalone server";
          security = "user";
          "map to guest" = "Bad User";
          "dns proxy" = "no";
        };
        # Samba shares
        backups = commonConfig // {
          path = "/bank/data/backups";
        };
        docs = commonConfig // {
          path = "/bank/data/docs";
        };
        media = commonConfig // {
          path = "/bank/data/media";
          "guest ok" = "yes";
        };
        pictures = commonConfig // {
          path = "/bank/data/pictures";
        };
      };
  };

  # Enable wsdd for Windows network discovery
  services.samba-wsdd = {
    enable = true;
    workgroup = "WORKGROUP";
    openFirewall = true;
  };
  # endregion Samba file sharing

  # region Podman (Docker-compatible container runtime)
  virtualisation.containers.enable = true;
  virtualisation = {
    oci-containers.backend = "podman";
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    containers.containersConf.settings = {
      unqualified-search-registries = [ "docker.io" ];
      engine = {
        compose_providers = [ "/run/current-system/sw/bin/podman-compose" ];
        compose_warning_logs = false;
      };
    };
  };
  # endregion Podman

  # region software
  programs.zsh.enable = true;
  programs.vim.enable = true;
  programs.vim.defaultEditor = true;

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/nas/nixos-config";
  };

  services.openssh = {
    enable = true;
    ports = [ 22 ];
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  services.fail2ban.enable = true;

  systemd.user.extraConfig = ''
    DefaultEnvironment="PATH=/run/current-system/sw/bin:/run/wrappers/bin:${lib.makeBinPath [ pkgs.bash ]}"
  '';

  environment.systemPackages = with pkgs; [
    # Basic packages for editing nix config
    git

    # System administration
    htop
    btop
    inetutils
    net-tools
    tcpdump
    dig.dnsutils

    # Hardware info and monitoring
    inxi
    lm_sensors
    pciutils
    usbutils
    smartmontools

    # ZFS utilities
    zfs
    zfstools

    # File utilities
    ncdu
    _7zz-nls
    ripgrep

    # Container tools
    dive
    podman-tui
    podman-compose
  ];
  # endregion software

  # region firewall
  networking.firewall = {
    enable = true;
    # allowedTCPPorts = [
    # ];
    # allowedUDPPorts = [
    # ];
  };
  # endregion firewall

  # region nix config
  system.stateVersion = "25.05";
  # endregion nix config
}
