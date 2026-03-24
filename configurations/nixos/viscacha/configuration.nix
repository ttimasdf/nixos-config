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
      default = "nixos-*";
      # default = "@saved";
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
  # https://bugzilla.kernel.org/show_bug.cgi?id=219721
  boot.blacklistedKernelModules = lib.trace "FIXME: blacklist spd5118 due to kernel bug #219721" [
    "spd5118"
  ];

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
    '';
  };

  fileSystems."/mnt/code" = {
    device = "/dev/mapper/crypt-code";
    fsType = "ntfs3";
    options = [ "defaults,rw,nofail,discard,nosuid,uid=1000,dmask=022,fmask=133" ];
  };
  fileSystems."/mnt/windows" = {
    device = "/dev/mapper/crypt-windows";
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

  rabitprivate.nixos.hosts.corpo.enable = true;
  rabitprivate.nixos.hosts.pentest.enable = true;
  # endregion network

  # region UI/UX
  rabit.nixos.gui.kde.enable = true;
  rabit.nixos.gui.l10n-chinese.enable = true;
  rabit.nixos.gui.font-dir.enable = true;
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
  # https://github.com/NixOS/nixos-hardware/blob/master/lenovo/legion/16irx9h/default.nix
  # https://github.com/NixOS/nixos-hardware/blob/master/common/gpu/nvidia/prime.nix
  # https://wiki.nixos.org/wiki/NVIDIA
  hardware.nvidia = {
    modesetting.enable = true;
    # ==== PRIME Settings
    # == Sync mode: dGPU to render, copy to iGPU
    prime.sync.enable = true;
    prime.offload.enable = false;
    # optional: create a specialisation for disabling NVIDIA GPU
    primeBatterySaverSpecialisation = false;

    # == Offload: iGPU render, use dGPU only when launched via `nvidia-offload` cmd
    # prime.offload.enable = true;
    # prime.offload.enableOffloadCmd = true;

    # == Reverse sync: dGPU render
    # prime.reverseSync.enable = true;

    # == Enable if using an external GPU via Thunderbolt/USB4 enclosure
    # prime.allowExternalGpu = true;
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
  programs.zsh.enable = true;
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # provides libfuse.so.2 for the AppImage
    fuse
    # It's usually a good idea to add these common dependencies
    # for whatever is *inside* the AppImage as well:
    stdenv.cc.cc.lib
    zlib
    glib
  ];

  programs.vim.enable = true;
  programs.vim.defaultEditor = true;

  programs.java.enable = true;
  programs.java.package = pkgs.jdk.override { enableJavaFX = true; };

  programs.kdeconnect.enable = true;
  services.mihomo.enable = true;
  services.mihomo.tunMode = true;
  services.mihomo.webui = pkgs.metacubexd;
  services.mihomo.configFile = "/home/u/Documents/clash-config/cfg-2aym2a2s/client.yml";
  rabit.nixos.http_proxy = "http://127.0.0.1:28888";

  programs.throne.enable = true;
  programs.throne.tunMode.enable = true;

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/u/Documents/nixos-config"; # sets NH_OS_FLAKE variable for you
  };

  services.flatpak.enable = true;

  # services.ollama = {
  #   enable = true;
  #   package = pkgs.ollama-cuda;
  # };

  # ssh
  # https://wiki.nixos.org/wiki/SSH
  services.openssh = {
    enable = true;
    ports = [ 54022 ];
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

  # Enable ddccontrol for controlling DDC/CI monitors
  services.ddccontrol.enable = true;

  # Add 'newuidmap' and 'sh' to the PATH for users' Systemd units.
  # Required for Rootless podman.
  systemd.user.extraConfig = ''
    DefaultEnvironment="PATH=/run/current-system/sw/bin:/run/wrappers/bin:${lib.makeBinPath [ pkgs.bash ]}"
  '';

  systemd.services."user@".serviceConfig = {
    TimeoutStopSec = "30s";
  };

  # Configure the global HTTP proxy for the podman service.
  systemd.services."podman".serviceConfig = lib.mkIf (config.rabit.nixos.http_proxy != null) {
    Environment = [
      "http_proxy=${config.rabit.nixos.http_proxy}"
      "https_proxy=${config.rabit.nixos.http_proxy}"
      "no_proxy=${config.rabit.nixos.no_proxy}"
    ];
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
    _7zz-nls
  ];

  # https://wiki.nixos.org/wiki/TPM
  security.tpm2.enable = true;
  # expose /run/current-system/sw/lib/libtpm2_pkcs11.so
  security.tpm2.pkcs11.enable = true;
  # TPM2TOOLS_TCTI and TPM2_PKCS11_TCTI env variables
  security.tpm2.tctiEnvironment.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.

  programs.traceroute.enable = true;
  programs.mtr.enable = true;
  programs.astral.enable = true;

  programs.appimage.enable = true;
  programs.appimage.binfmt = true;

  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
  programs.fido-linux-id.enable = true;
  programs.wireshark.enable = true;
  programs.wireshark.package = pkgs.wireshark;
  programs.wireshark.dumpcap.enable = true;
  programs.wireshark.usbmon.enable = true;

  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/programs/ghidra.nix
  # programs.ghidra.enable = true;
  # programs.ghidra.package = pkgs.ghidra-mod-with-extensions;


  #endregion software

  #region containers

  hardware.nvidia-container-toolkit.enable = true;

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
      unqualified-search-registries = ["docker.io"];

      engine = {
        compose_providers = ["/run/current-system/sw/bin/podman-compose"];
        compose_warning_logs = false;
      };

      registry = [
        {
          prefix = "docker.io";
          insecure = false;
          blocked = false;
          location = "docker.io";
          mirror = [
            { location = "docker.milktea.info"; }
            { location = "docker.nju.edu.cn"; }
          ];
        }
        {
          prefix = "ghcr.io";
          insecure = false;
          blocked = false;
          location = "ghcr.io";
          mirror = [
            { location = "ghcr.nju.edu.cn"; }
          ];
        }
      ];
    };

    containers.registries.search = [
      "docker.io"
    ];

    containers.storage.settings = {
      storage.driver = "btrfs";
    };
  };

  #endregion containers

  #region VMs
  # https://wiki.nixos.org/wiki/Virt-manager
  virtualisation.libvirtd = {
    enable = true;
    qemu.vhostUserPackages = with pkgs; [ virtiofsd ];
  };
  programs.virt-manager.enable = true;
  #endregion VMs

  #region configurations
  # Fix uv python ssl.SSLCertVerificationError
  environment.etc.certfile = {
    source = "/etc/ssl/certs/ca-bundle.crt";
    target = "ssl/cert.pem";
  };
  # ~/.local/bin in PATH for `uv tool install`
  environment.localBinInPath = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;
  programs.ssh.startAgent = true;

  # Open ports in the firewall.
  networking.firewall = {
    enable = true;
    # Allow mihomo/easytier TUN mode to work with system stack
    trustedInterfaces = [
      "mihomo0"
      "easytier0"
      "astral"
    ];
    checkReversePath = "loose";

    allowedTCPPorts = [
      3006    # hapi
      22000   # syncthing
      53317   # localsend
    ];
    allowedUDPPorts = [
      3006    # hapi
      22000   # syncthing
      53317   # localsend
    ];
  };

  rabitprivate.nixos.cacerts.mitmca.enable = true;
  # endregion configurations

  # region nix config

  nixpkgs.config = {
    # Allow unfree packages
    allowUnfree = true;
    # Enable CUDA support for PyTorch and related packages
    # cudaSupport = true;
    # Ada Lovelace support for LLM inference
    # cudaCapabilities = [ "8.9" ];

    permittedInsecurePackages = [
      lib.warn "Enabling insecure package qtwebengine-5.15.19 due to unicom-cloud-desktop dependency"
        "qtwebengine-5.15.19"
      lib.warn "Enabling insecure package openssl-1.1.1w due to nur.repos.yakkhini.dingtalk dependency"
        "openssl-1.1.1w"
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
