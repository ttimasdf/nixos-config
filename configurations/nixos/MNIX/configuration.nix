# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ flake, config, lib, pkgs, ... }:

let
  inherit (flake.inputs) self;
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # region boot & kernel
  boot.lanzaboote = {
    # Configuration for the `systemd-boot`. See `loader.conf(5)` for supported values.
    settings = {
      timeout = config.boot.loader.timeout;
      console-mode = config.boot.loader.systemd-boot.consoleMode;
      editor = false;
      # default = "nixos-*";
      default = "@saved";
      # If this is disabled, the firmware interface may still be reached by using the f key.
      auto-firmware = false;
      reboot-for-bitlocker = true;
    };
  };

  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };
  # endregion boot & kernel

  # region user settings
  rabit.nixos.myusers = ["toor"];
  # endregion user settings

  # region partitions
  # https://nixos.wiki/wiki/Full_Disk_Encryption
  # https://www.man7.org/linux/man-pages/man8/cryptsetup.8.html
  # sudo cryptsetup open /dev/nvme0n1p3 --type bitlk --key-file /root/.secrets/24860161-2878-4FA2-A9D2-4238687ED9BF.BEK windows
  # endregion partitions

  # region network
  networking.hostName = "MNIX"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Define the NetworkManager dispatcher script
  # networking.networkmanager.dispatcherScripts = [
  #   {
  #     source = pkgs.writeText "nm-wifiap-firewall" ''
  #       #!${pkgs.bash}/bin/bash

  #       # nixos-firewall-tool depends on iptables
  #       export PATH="$PATH:${pkgs.iptables}/bin"

  #       # The UUID of your NetworkManager hotspot profile
  #       HOTSPOT_UUID="d27cf42f-9550-4c3d-9858-dda05090d536"

  #       # The interface of the connection is passed as the first argument
  #       INTERFACE=$1

  #       # The action (up/down) is passed as the second argument
  #       ACTION=$2

  #       # Logging for troubleshooting
  #       logger "NetworkManager dispatcher script for hotspot firewall triggered for interface $INTERFACE with action $ACTION and connection UUID $CONNECTION_UUID"

  #       open_ports() {
  #           logger "Opening firewall ports for hotspot on $INTERFACE"
  #           /run/current-system/sw/bin/nixos-firewall-tool open udp 67
  #           /run/current-system/sw/bin/nixos-firewall-tool open udp 53
  #           /run/current-system/sw/bin/nixos-firewall-tool open tcp 53
  #       }

  #       close_ports() {
  #           logger "Closing firewall ports for hotspot on $INTERFACE"
  #           /run/current-system/sw/bin/nixos-firewall-tool reset
  #       }

  #       if [ "$CONNECTION_UUID" = "$HOTSPOT_UUID" ]; then
  #           case "$ACTION" in
  #               up)
  #                   open_ports
  #                   ;;
  #               down)
  #                   close_ports
  #                   ;;
  #               *)
  #                   ;;
  #           esac
  #       fi
  #     '';
  #   }
  # ];


  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  rabit.nixos.hosts.corpo.enable = true;
  rabit.nixos.hosts.pentest.enable = true;
  rabit.nixos.gui.font-dir.enable = true;
  # endregion network

  # region UI/UX
  rabit.nixos.gui.kde.enable = true;
  rabit.nixos.gui.l10n-chinese.enable = true;
  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    #keyMap = "us";
    #useXkbConfig = true; # use xkb.options in tty.
  };

  # Configure keymap in X11
  services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Provided by:
  # https://github.com/NixOS/nixos-hardware/blob/9ed85f8afebf2b7478f25db0a98d0e782c0ed903/common/gpu/nvidia/prime.nix#L7

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Shows battery charge of connected devices on supported
        # Bluetooth adapters. Defaults to 'false'.
        Experimental = true;
        # When enabled other devices can connect faster to us, however
        # the tradeoff is increased power consumption. Defaults to
        # 'false'.
        FastConnectable = false;
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on. Defaults to 'true'.
        AutoEnable = true;
      };
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;
  # endregion UI/UX

  # region software
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Add any missing dynamic libraries for unpackaged programs
    # here, NOT in environment.systemPackages
  ];

  programs.vim.enable = true;
  programs.vim.defaultEditor = true;

  programs.java.enable = true;
  programs.java.package = pkgs.jdk.override { enableJavaFX = true; }; # fix javafx
  
  # fimware service
  services.fwupd.enable = true;
  # Thunderbolt service
  services.hardware.bolt.enable = true;

  # fingerprint scanner https://wiki.nixos.org/wiki/Fingerprint_scanner
  # Install the driver
  services.fprintd.enable = true;
  # If simply enabling fprintd is not enough, try enabling fprintd.tod...
  # services.fprintd.tod.enable = true;
  # ...and use one of the next four drivers
  # services.fprintd.tod.driver = pkgs.libfprint-2-tod1-goodix; # Goodix driver module
  # services.fprintd.tod.driver = pkgs.libfprint-2-tod1-elan; # Elan(04f3:0c4b) driver
  # services.fprintd.tod.driver = pkgs.libfprint-2-tod1-vfs0090; # (Marked as broken as of 2025/04/23!) driver for 2016 ThinkPads
  # services.fprintd.tod.driver = pkgs.libfprint-2-tod1-goodix-550a; # Goodix 550a driver (from Lenovo)

  # however for focaltech 2808:a658, use fprintd with overidden package (without tod)
  # services.fprintd.package = pkgs.fprintd.override {
  #   libfprint = pkgs.libfprint-focaltech-2808-a658;
  # };
  security.pam.services.login.fprintAuth = false;
  security.pam.services.gdm-fingerprint = lib.mkIf (config.services.fprintd.enable) {
    text = ''
      auth       required                    pam_shells.so
      auth       requisite                   pam_nologin.so
      auth       requisite                   pam_faillock.so      preauth
      auth       required                    ${pkgs.fprintd}/lib/security/pam_fprintd.so
      auth       optional                    pam_permit.so
      auth       required                    pam_env.so
      auth       [success=ok default=1]      ${pkgs.gdm}/lib/security/pam_gdm.so
      auth       optional                    ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so

      account    include                     login

      password   required                    pam_deny.so

      session    include                     login
      session    optional                    ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
    '';
  };

  services.mihomo.enable = true;
  services.mihomo.tunMode = true;
  services.mihomo.webui = pkgs.metacubexd;
  services.mihomo.configFile = "/home/toor/Documents/clash-config/client.yml";

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/toor/Documents/nixos-config"; # sets NH_OS_FLAKE variable for you
  };

  services.flatpak.enable = true;

  # Tailscale
  services.tailscale.enable = true;

  # ssh
  # https://wiki.nixos.org/wiki/SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };


  # https://wiki.nixos.org/wiki/Fail2ban
  services.fail2ban = {
    enable = true;
  };

  ## Container config

  # hardware.nvidia-container-toolkit.enable = true;

  # Enable common container config files in /etc/containers
  virtualisation.containers.enable = true;
  virtualisation = {
    oci-containers.backend = "podman";
    podman = {
      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
    containers.containersConf.settings = {
      engine = {
        compose_providers = ["/run/current-system/sw/bin/podman-compose"];
        compose_warning_logs = false;
      };
    };
  };

  #region VMs
  # https://wiki.nixos.org/wiki/Virt-manager
  virtualisation.libvirtd = {
    enable = true;
    qemu.vhostUserPackages = with pkgs; [ virtiofsd ];
  };
  programs.virt-manager.enable = true;
  #endregion VMs

  # Add 'newuidmap' and 'sh' to the PATH for users' Systemd units.
  # Required for Rootless podman.
  systemd.user.extraConfig = ''
    DefaultEnvironment="PATH=/run/current-system/sw/bin:/run/wrappers/bin:${lib.makeBinPath [ pkgs.bash ]}"
  '';

  systemd.services."user@".serviceConfig = {
    TimeoutStopSec = "30s";
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    # Basic packages for editing nix config
    git

    # sysadmin
    inetutils   # ftp  hostname  ifconfig  telnet  tftp  traceroute  whois
    net-tools   # netstat
    htop
    tcpdump
    dig.dnsutils

    # Hardware info
    pciutils
    usbutils
    intel-gpu-tools

    # Disk Encryption
    #cryptsetup
    exfatprogs

    # containers
    dive # look into docker image layers
    podman-tui # status of containers in the terminal
    #docker-compose # start group of containers for dev
    podman-compose # start group of containers for dev

    # Archive
    rar
    unzip-nls
    zip-nls
    _7zz-natspec

    # Development
    uv
  ];

  # Fix uv python ssl.SSLCertVerificationError
  environment.etc.certfile = {
    source = "/etc/ssl/certs/ca-bundle.crt";
    target = "ssl/cert.pem";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.

  programs.traceroute.enable = true;
  programs.mtr.enable = true;

  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
  programs.wireshark.enable = true;
  programs.wireshark.package = pkgs.wireshark-qt;
  programs.wireshark.dumpcap.enable = true;
  programs.wireshark.usbmon.enable = true;
  programs.ghidra.enable = true;
  programs.ghidra.package = pkgs.ghidra-mod-with-extensions;
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;
  programs.ssh.startAgent = true;

  # Open ports in the firewall.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      #22000   # syncthing
      53317   # localsend
      8888    # MITM
      4444    # reverse listener
    ];
    allowedUDPPorts = [
      #22000   # syncthing
      53317   # localsend
      67      # dhcp
      53      # dns
    ];
  };

  security.pki.certificateFiles = [
    (toString self + "/files/cacerts/mitmca.pem")
  ];
  # endregion software

  # region nix config
  systemd.services."nix-daemon".serviceConfig = {
    Environment = [
      "http_proxy=http://127.0.0.1:7897"
      "https_proxy=http://127.0.0.1:7897"
      "no_proxy=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,172.29.0.0/16,::1"
    ];
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?
  # endregion nix config
}
