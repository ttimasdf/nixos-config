{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    # File Management & Search
    fsearch
    syncthing
    syncthingtray
    localsend

    # Social & Communication
    # dingtalk

    # Note Taking & Documentation
    siyuan
    obsidian
    typora
    # pandoc        # enabled by programs.pandoc.enable

    # Web Browsers & Download Tools
    # firefox       # enabled by programs.firefox.enable
    microsoft-edge
    # chromium      # enabled by programs.chromium.enable
    ddgr
    aria2
    wormhole-cli

    # Office Suite
    wpsoffice-cn-fcitx

    # Password Management
    keepassxc
    git-credential-keepassxc

    # Screenshot & Recording
    flameshot
    # asciinema     # enabled by programs.asciinema.enable
    obs-studio

    # Media Players
    vlc
    qmplay2
    unlock-music-cli

    # Networking
    proxychains-ng
    tail-tray
    easytier

    # Remote Access
    rustdesk-flutter
    virt-viewer
    sshpass
  ];

  # Add symlink for edge for Apps to work
  home.file = {
    ".local/bin/microsoft-edge-stable".source = "${pkgs.microsoft-edge}/bin/microsoft-edge";
  };

  # Make Puppeteer use the Home Manager-managed Chromium build instead of
  # downloading browser binaries into the user's profile/cache.
  home.sessionVariables =
    lib.optionalAttrs config.programs.chromium.enable {
      PUPPETEER_EXECUTABLE_PATH = "${config.programs.chromium.package}/bin/chromium";
    }
    // {
      # Skip Puppeteer's bundled browser downloads when the corresponding
      # browser is already provided by this Home Manager profile.
      PUPPETEER_SKIP_DOWNLOAD = lib.boolToString config.programs.chromium.enable;
      PUPPETEER_FIREFOX_SKIP_DOWNLOAD = lib.boolToString config.programs.firefox.enable;
      PUPPETEER_CHROME_SKIP_DOWNLOAD = lib.boolToString config.programs.chromium.enable;
    };

  programs.firefox.enable = true;
  programs.chromium = {
    enable = true;
    package = pkgs.ungoogled-chromium;
    # package = pkgs.ungoogled-chromium.override { enableWideVine = true; };
    # package = pkgs.google-chrome;
    nativeMessagingHosts = [ pkgs.kdePackages.plasma-browser-integration ];
    extensions = [
      # NeverDecaf/chromium-web-store
      {
        id = "ocaahdebbfolfmndjeplogmgcagdmblk";
        updateUrl = "https://raw.githubusercontent.com/NeverDecaf/chromium-web-store/master/updates.xml";
      }
      # { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
      # { id = "pfnededegaaopdmhkdmcofjmoldfiped"; } # Proxy SwitchyOmega 3 (ZeroOmega)
      # { id = "dhdgffkkebhmkfjojejmpbldmpobfkfo"; } # Tampermonkey
      # { id = "bhchdcejhohfmigjafbampogmaanbfkg"; } # User-Agent Switcher and Manager
      # { id = "hlkenndednhfkekhgcdicdfddnkalmdm"; } # Cookie-Editor
    ];
  };
  # programs.obsidian.enable = true;
  programs.pandoc.enable = true;
  programs.asciinema.enable = true;
}
