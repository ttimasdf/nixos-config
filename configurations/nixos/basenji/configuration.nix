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
  boot.loader.systemd-boot.enable = true;
  # Kernel+initrd live on the ESP and it is 249 MiB here, so depth is capped at 3.
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true; # persists via efidisk0
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200n8" ];
  boot.initrd.systemd = {
    enable = true;
    repart.enable = true;
  };

  boot.kernelPackages = pkgs.linuxPackages;
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  boot.supportedFilesystems.zfs = true;
  # ext4 root: a force-import would also pick up exported or foreign pools.
  boot.zfs.forceImportRoot = false;
  # Nothing else references the pool, so NixOS would not generate zfs-import@bank.
  boot.zfs.extraPools = [ "bank" ];
  networking.hostId = "a8c4e2f1";
  # endregion boot & kernel

  # region user settings
  rabit.nixos.myusers = [ "nas" ];
  time.timeZone = "Asia/Shanghai";
  # endregion user settings

  # region network
  networking.hostName = "basenji";
  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.nftables.enable = true;
  # MAC-pinned so a slot shuffle cannot rename the legs.
  systemd.network.links."10-basenji-trunk" = {
    matchConfig.MACAddress = "BC:24:11:58:B7:0E";
    linkConfig.Name = "enp6s18";
  };
  # The second leg is on the upstream L2: keep the link up but completely deaf,
  # or every 0.0.0.0 listener is reachable from the CPE segment.
  systemd.network.links."05-basenji-upstream" = {
    matchConfig.MACAddress = "BC:24:11:BE:A6:FE";
    linkConfig.Name = "enp6s19";
  };
  systemd.network.networks."40-enp6s19" = {
    matchConfig.Name = "enp6s19";
    linkConfig.RequiredForOnline = false;
    networkConfig = {
      DHCP = "no";
      IPv6AcceptRA = "no";
      LinkLocalAddressing = "no";
      ConfigureWithoutCarrier = false;
    };
  };
  services.qemuGuest.enable = true;

  services.resolved.settings.Resolve = lib.mkIf (config.services.resolved.enable) {
    FallbackDNS = [
      "223.5.5.5#dns.alidns.com" "1.12.12.12#doh.pub"
      "223.6.6.6#dns.alidns.com" "120.53.53.53#doh.pub"
      "2400:3200::1#dns.alidns.com" "2400:3200:baba::1#dns.alidns.com"
    ];
  };
  # endregion network

  # region ZFS pool configuration
  # vdev paths stay slot-based: the import is GUID-driven, so they are cosmetic.
  #
  # by-id names use VPD 0x83, which the hypervisor fills with the slot, so they
  # re-point after a slot shuffle; VPD 0x80 carries the real serial.
  services.udev.extraRules = ''
    SUBSYSTEM=="block", KERNEL=="sd[a-z]", ENV{ID_SCSI_SERIAL}=="?*", SYMLINK+="disk/by-serial/$env{ID_SCSI_SERIAL}"
  '';

  services.zfs.autoScrub.enable = true;
  services.zfs.autoScrub.pools = [ "bank" ];
  services.zfs.trim.enable = true;
  # endregion ZFS pool configuration

  # region Cockpit web management
  services.cockpit = {
    enable = true;
    port = 9090;
    openFirewall = false; # no `address` option here, the per-leg rules scope it
    allowed-origins = [ "*" ];
    settings = {
      WebService = {
        ProtocolHeader = "X-Forwarded-Proto";
        ForwardedForHeader = "X-Forwarded-For";
      };
    };
    plugins = with pkgs; [
      cockpit-podman
      cockpit-files
    ];
  };
  # endregion Cockpit web management

  # region Samba file sharing
  # The datasets are native zfs mounts (not fstab), and their nested zfsutil
  # units race the pool import, so smbd must order after zfs-mount.
  systemd.services.samba-smbd = {
    wants = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" "zfs-import.target" ];
    requires = [ "zfs-import.target" ];
  };

  services.samba = {
    enable = true;
    openFirewall = false; # per-leg rules below govern
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
          # Bind at the app level too: otherwise nmbd advertises on every
          # attached L2 and smbd accepts on any address.
          interfaces = "lo enp6s18";
          "bind interfaces only" = "yes";
          # One file per source IP: log.smbd never records the client address.
          "log level" = "1 auth:3";
          "log file" = "/var/log/samba/log.%I";
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

  services.samba-wsdd = {
    enable = true;
    workgroup = "WORKGROUP";
    openFirewall = false; # per-leg rules below govern
    interface = "enp6s18"; # else it multicasts on every leg
  };
  # Without rotation the per-IP logs accumulate one file per client forever.
  services.logrotate.settings.samba = {
    files = [ "/var/log/samba/log.*" ];
    frequency = "weekly";
    rotate = 4;
    compress = true;
    missingok = true;
    notifempty = true;
    create = "0640 root root";
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
    openFirewall = false; # per-leg rules below govern
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  services.fail2ban.enable = true;

  environment.systemPackages = with pkgs; [
    git
    nix-output-monitor

    htop
    btop
    inetutils
    net-tools
    tcpdump
    dig.dnsutils

    inxi
    lm_sensors
    pciutils
    usbutils
    smartmontools

    zfs
    zfstools

    ncdu
    _7zz-nls
    ripgrep

    dive
    podman-tui
    podman-compose
  ];
  # endregion software

  # region firewall
  # Per-leg INPUT enumeration: every listener is named on the leg it serves.
  # INVARIANT: openFirewall stays false on every service module — one `true`
  # re-adds a wildcard allow and this enumeration stops being the truth.
  networking.firewall = {
    enable = true;
    interfaces.enp6s18 = {
      allowedTCPPorts = [
        22 # ssh
        139 # smb (netbios session)
        445 # smb
        5357 # wsdd http
        8384 # syncthing GUI
        9090 # cockpit
        22000 # syncthing transfer
      ];
      allowedUDPPorts = [
        137 # netbios name service
        138 # netbios datagram
        3702 # wsdd discovery
        21027 # syncthing local discovery
        22000 # syncthing QUIC
      ];
    };
  };
  # endregion firewall

  # region nix config
  system.stateVersion = "25.05";
  # endregion nix config
}
