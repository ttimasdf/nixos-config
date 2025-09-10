# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # region boot & kernel
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
  # systemd-boot is configured by lanzaboote
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.systemd-boot.rebootForBitlocker = true;
  # boot.loader.systemd-boot.configurationLimit = 5;

  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };
  # endregion boot & kernel

  # region partitions
  # https://nixos.wiki/wiki/Full_Disk_Encryption
  # sudo cryptsetup open /dev/nvme0n1p3 --type bitlk --key-file /root/.secrets/24860161-2878-4FA2-A9D2-4238687ED9BF.BEK windows
  environment.etc.crypttab = {
    mode = "0600";
    text = ''
      # <volume-name> <encrypted-device>                        [key-file]                                              [options]
      crypt-windows   UUID=72932a38-260b-4616-af6f-748f396852f6 /root/.secrets/24860161-2878-4FA2-A9D2-4238687ED9BF.BEK bitlk,read-only
      crypt-vm-images UUID=a854d8d7-9e44-4bf2-b02a-a995c30209f0 /root/.secrets/a854d8d7-9e44-4bf2-b02a-a995c30209f0.key discard
    '';
  };

  fileSystems."/mnt/vm-images" =
    { device = "/dev/mapper/crypt-vm-images";
      options = [ "defaults,discard" ];
    };
  # endregion partitions

  # region network
  networking.hostName = "Nokia-N97"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  # endregion network

  # region UI/UX
  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    #keyMap = "us";
    #useXkbConfig = true; # use xkb.options in tty.
  };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  services = {
    desktopManager.plasma6.enable = true;
    displayManager.sddm.enable = true;
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };
  };

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # https://nixos.wiki/wiki/Fonts
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      sarasa-gothic         # Chinese font
      #noto-fonts
      nerd-fonts.noto
      noto-fonts-cjk-sans   # CJK font
      noto-fonts-emoji
      liberation_ttf        # include serif, sans serif, mono
      nerd-fonts.liberation
      #fira-code
      nerd-fonts.fira-code
      fira-code-symbols
      #mplus-outline-fonts.githubRelease  # Japanese font
    ];

    # enable /run/current-system/sw/share/X11/fonts
    fontDir.enable = true;

    fontconfig = {
      #useEmbeddedBitmaps = true;        # fix Noto Color Emoji in Firefox
      defaultFonts = {
        serif = [  "Liberation Serif" "Noto Serif CJK SC" ];
        sansSerif = [ "Liberation Sans" "Sarasa UI SC" "Noto Sans CJK SC" ];
        monospace = [ "FiraCode Nerd Font" "Sarasa Mono SC" "Noto Sans Mono CJK SC" ];
      };
    };
  };

  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-gtk             # alternatively, kdePackages.fcitx5-qt
      fcitx5-chinese-addons  # table input method support
      fcitx5-nord            # a color theme
    ];
  };

  hardware.nvidia.prime = {
    reverseSync.enable = true;
    # Enable if using an external GPU
    allowExternalGpu = true;
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

  # region user
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.u = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      tree
    ];
  };
  # endregion user

  # region software
  nixpkgs.config.allowUnfree = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Add any missing dynamic libraries for unpackaged programs
    # here, NOT in environment.systemPackages
  ];

  # https://nixos.wiki/wiki/Flatpak
  services.flatpak.enable = true;
  #systemd.services.flatpak-repo = {
  #  wantedBy = [ "multi-user.target" ];
  #  path = [ pkgs.flatpak ];
  #  script = ''
  #    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  #  '';
  #};

  programs.firefox.enable = true;
  programs.vim.enable = true;
  programs.vim.defaultEditor = true;


  # Enable common container config files in /etc/containers
  virtualisation.containers.enable = true;
  virtualisation = {
    podman = {
      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    # Basic packages for editing nix config
    git

    # Secure Boot
    sbctl
    # Disk Encryption
    cryptsetup

    # KDE optional packages
    kdePackages.partitionmanager
    kdePackages.ksystemlog
    kdePackages.plasma-systemmonitor
    kdePackages.sddm-kcm
    kdePackages.flatpak-kcm

    kdePackages.discover
    kdePackages.kcalc
    kdePackages.kclock

    wayland-utils
    wl-clipboard
    xclip

    # SysAdmin
    kdiff3
    freerdp
    hardinfo2

    # containers
    dive # look into docker image layers
    podman-tui # status of containers in the terminal
    #docker-compose # start group of containers for dev
    podman-compose # start group of containers for dev

    # Productivity
    vlc
    keepassxc
    git-credential-keepassxc

    # Development
    uv
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  # endregion software

  # region nix config
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.substituters = [ "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" ];

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

