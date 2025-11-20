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

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };
  # endregion boot & kernel

  # region user settings
  rabit.nixos.myusers = ["u"];
  # endregion user settings

  # region partitions
  # https://nixos.wiki/wiki/Full_Disk_Encryption
  # https://www.man7.org/linux/man-pages/man8/cryptsetup.8.html
  # sudo cryptsetup open /dev/nvme0n1p3 --type bitlk --key-file /root/.secrets/24860161-2878-4FA2-A9D2-4238687ED9BF.BEK windows
  environment.etc.crypttab = {
    mode = "0600";
    text = ''
      # <volume-name> <encrypted-device>                        [key-file]                                              [options]
      crypt-windows   UUID=72932a38-260b-4616-af6f-748f396852f6 /root/.secrets/24860161-2878-4FA2-A9D2-4238687ED9BF.BEK bitlk,discard,nofail
      crypt-code      UUID=1e0fec8f-f4fc-4c26-b91a-cdd932899b9d /root/.secrets/AF91DAF0-D5B6-405F-9F6D-AC53F5F557CB.BEK bitlk,discard,nofail
      crypt-vm-images UUID=a854d8d7-9e44-4bf2-b02a-a995c30209f0 /root/.secrets/a854d8d7-9e44-4bf2-b02a-a995c30209f0.key discard,nofail
    '';
  };

  fileSystems."/mnt/vm-images" = {
    device = "/dev/mapper/crypt-vm-images";
    options = [ "defaults,nofail,discard" ];
  };
  fileSystems."/mnt/code" = {
    device = "/dev/mapper/crypt-code";
    fsType = "ntfs3";
    options = [ "defaults,rw,nofail,discard,nosuid,uid=1000,dmask=022,fmask=133" ];
  };

  # endregion partitions

  # region network
  networking.hostName = "viscacha"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Define the NetworkManager dispatcher script
  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeText "nm-wifiap-firewall" ''
        #!${pkgs.bash}/bin/bash

        # nixos-firewall-tool depends on iptables
        export PATH="$PATH:${pkgs.iptables}/bin"

        # The UUID of your NetworkManager hotspot profile
        HOTSPOT_UUID="95d537de-b03a-4d9a-b5f4-30e2c759e7b0"

        # The interface of the connection is passed as the first argument
        INTERFACE=$1

        # The action (up/down) is passed as the second argument
        ACTION=$2

        # Logging for troubleshooting
        logger "NetworkManager dispatcher script for hotspot firewall triggered for interface $INTERFACE with action $ACTION and connection UUID $CONNECTION_UUID"

        open_ports() {
            logger "Opening firewall ports for hotspot on $INTERFACE"
            /run/current-system/sw/bin/nixos-firewall-tool open udp 67
            /run/current-system/sw/bin/nixos-firewall-tool open udp 53
            /run/current-system/sw/bin/nixos-firewall-tool open tcp 53
        }

        close_ports() {
            logger "Closing firewall ports for hotspot on $INTERFACE"
            /run/current-system/sw/bin/nixos-firewall-tool reset
        }

        if [ "$CONNECTION_UUID" = "$HOTSPOT_UUID" ]; then
            case "$ACTION" in
                up)
                    open_ports
                    ;;
                down)
                    close_ports
                    ;;
                *)
                    ;;
            esac
        fi
      '';
    }
  ];


  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  rabit.nixos.hosts.corpo.enable = true;
  rabit.nixos.hosts.pentest.enable = true;
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
  hardware.nvidia.primeBatterySaverSpecialisation = false;
  hardware.nvidia.prime = {
    # Use NVIDIA GPU for rendering
    sync.enable = true;
    offload.enable = false;
    # Use Intel GPU for rendering
    reverseSync.enable = false;
    # Enable if using an external GPU via Thunderbolt/USB4 enclosure
    # allowExternalGpu = true;
  };

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
  # services.printing.enable = true;

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
  programs.java.package = pkgs.jdk.override { enableJavaFX = true; };

  services.mihomo.enable = true;
  services.mihomo.tunMode = true;
  services.mihomo.webui = pkgs.metacubexd;
  services.mihomo.configFile = "/home/u/Documents/clash-config/cfg-2aym2a2s/client.yml";

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/u/Documents/nixos-config"; # sets NH_OS_FLAKE variable for you
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

    # Disk Encryption
    cryptsetup

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

    # GhydraMCP Client
    ghidra-custom-extensions.ghydra-mcp.client
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
  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/tools/security/ghidra/extensions.nix
  programs.ghidra.package = pkgs.ghidra.withExtensions (exts:
    (with exts; [
      findcrypt
      # ghidra-delinker-extension
      # ghidra-firmware-utils
      # ghidra-golanganalyzerextension
      # ghidraninja-ghidra-scripts
      # gnudisassembler
      # kaiju
      # lightkeeper
      # machinelearning
      ret-sync
      sleighdevtools
      # wasm
    ]) ++ (with pkgs.ghidra-custom-extensions; [
      ghidraninja-ghidra-scripts
      ghidrassist-mcp
      ghydra-mcp
    ])
  );

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;
  programs.ssh.startAgent = true;

  # Open ports in the firewall.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22000   # syncthing
      53317   # localsend
    ];
    allowedUDPPorts = [
      22000   # syncthing
      53317   # localsend
    ];
  };

  security.pki.certificateFiles = [
    (toString self + "/files/cacerts/mitmca.pem")
  ];
  # endregion software

  # region nix config
  systemd.services."nix-daemon".serviceConfig = {
    Environment = [
      "http_proxy=http://127.0.0.1:28888"
      "https_proxy=http://127.0.0.1:28888"
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
