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

  # region boot & kernel — EFI: systemd-boot (grub retired 2026-10-25 after the
  # version-skew grub-rescue incident; see progress/2026-10-25-basenji-migration.md).
  # NOTE: boot.uki exists at our pin but only BUILDS the artifact (system.build.uki)
  # — no installer wiring into systemd-boot yet. Revisit on nixpkgs bump.
  boot.loader.systemd-boot.enable = true;
  # FIXME(2026-10-25): ESP is only 249M (image default) and under systemd-boot
  # the kernel+initrd (~45MB/gen w/ zfs initrd) live ON the ESP — rollback depth
  # is capped at 3. Rebuild the OS disk with image bootSize >= 1G at the next
  # calm window (fresh-rootfs recipe; /bank pool untouched).
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;  # persists via efidisk0
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200n8" ];  # qm terminal
  boot.initrd.systemd = {
    enable = true;
    repart.enable = true;
  };

  boot.kernelPackages = pkgs.linuxPackages;
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  # ZFS support for the raid-z pool "bank"
  boot.supportedFilesystems.zfs = true;
  # Root fs is ext4 — no zfs root to force-import (silences the 26.11 warning;
  # force-import risks re-importing exported/foreign pools — off is correct here)
  boot.zfs.forceImportRoot = false;
  # Declare the non-root pool: generates zfs-import@bank (loads the
  # file:// keylocation key at boot) + orders zfs-mount.service. Without this,
  # NixOS doesn't know the pool exists once no fileSystems entries reference it.
  boot.zfs.extraPools = [ "bank" ];
  # Key sync: sops renders the pool key to /run/secrets (initrd, pre-import);
  # copy it onto the keylocation path before import. Leading dash = tolerant:
  # if sops ever fails, the last-synced on-disk key still loads the pool.
  systemd.services."zfs-import@bank" = {
    serviceConfig.ExecStartPre = [
      "-${pkgs.coreutils}/bin/install -o root -g root -m 0600 ${config.sops.secrets."zpool-bank.key".path} /root/.secrets/zpool-bank.key"
    ];
  };
  # ZFS requires networking.hostId to be set
  networking.hostId = "a8c4e2f1";

  # endregion boot & kernel

  # region user settings
  rabit.nixos.myusers = [ "nas" ];
  time.timeZone = "Asia/Shanghai";
  # endregion user settings

  # region network
  networking.hostName = "basenji";
  # FLEET CONVENTION (2026-10-24): net0 = new zone primary, net1 = old-LAN backup.
  # MAC-pinned long names (natural predictable names, slot-shift-proof).
  # enp6s18 = net0 = VLAN 30 DEFAULT (10.66.30.7 via edge-01).
  # enp6s19 = net1 = old-LAN backup (direct L2 reach from 6.6/16 hosts; no
  #            default route — dies at S6).
  networking.useDHCP = false;
  systemd.network.links."10-basenji-vlan30" = {
    matchConfig.MACAddress = "BC:24:11:58:B7:0E";
    linkConfig.Name = "enp6s18";
  };
  networking.interfaces.enp6s18.ipv4.addresses = [ { address = "10.66.30.7"; prefixLength = 24; } ];
  # Default egress via edge-01 (FORWARD accept pre-S3; zone policy lands at S3).
  # Also covers all 10.66/16 — no separate return route needed.
  networking.defaultGateway = { address = "10.66.30.1"; interface = "enp6s18"; };
  systemd.network.links."05-basenji-oldlan" = {
    matchConfig.MACAddress = "BC:24:11:BE:A6:FE";
    linkConfig.Name = "enp6s19";
  };
  networking.interfaces.enp6s19.ipv4.addresses = [ { address = "6.6.1.1"; prefixLength = 16; } ];
  networking.nameservers = [ "10.66.10.1" "6.6.90.1" ];
  # PVE guest-agent integration (agent:1 already set on VM 131)
  services.qemuGuest.enable = true;
  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/tasks/network-interfaces-systemd.nix
  networking.useNetworkd = true;
  networking.nftables.enable = true;

  services.resolved.settings.Resolve = lib.mkIf (config.services.resolved.enable) {
    # DNSStubListener = false;
    # compiled-in fallback DNS:
    # 1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google 9.9.9.9#dns.quad9.net
    # 1.0.0.1#cloudflare-dns.com 8.8.4.4#dns.google 149.112.112.112#dns.quad9.net
    # 2606:4700:4700::1111#cloudflare-dns.com 2001:4860:4860::8888#dns.google 2620:fe::fe#dns.quad9.net
    # 2606:4700:4700::1001#cloudflare-dns.com 2001:4860:4860::8844#dns.google 2620:fe::9#dns.quad9.net
    FallbackDNS = [
      "223.5.5.5#dns.alidns.com" "1.12.12.12#doh.pub"
      "223.6.6.6#dns.alidns.com" "120.53.53.53#doh.pub"
      "2400:3200::1#dns.alidns.com" "2400:3200:baba::1#dns.alidns.com"
    ];
  };
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
    plugins = with pkgs; [
      # cockpit-zfs dropped: cockpitPath deps collide in depsEnv (libudev).
      # cockpit-file-sharing dropped: yarn offline build fails at this pin.
      # Revisit both on the next nixpkgs bump.
      cockpit-podman
      cockpit-files
    ];
  };

  # endregion Cockpit web management

  # region Samba file sharing
  # Ensure samba starts after the ZFS datasets are mounted. The bank datasets
  # have NATIVE zfs mountpoints — they are mounted by zfs-mount.service (NOT
  # fileSystems/fstab; nested zfsutil mount units race each other and the
  # pool import). This was the real smbd-dead-since-June bug chain. 2026-10-26.
  systemd.services.samba-smbd = {
    wants = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" "zfs-import.target" ];
    requires = [ "zfs-import.target" ];
  };

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

  environment.systemPackages = with pkgs; [
    # Basic packages for editing nix config
    git
    nix-output-monitor

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
    # Allow easytier TUN mode to work with system stack
    trustedInterfaces = [ "easytier0" ];
  };
  # endregion firewall

  # region nix config
  system.stateVersion = "25.05";
  # endregion nix config
}
