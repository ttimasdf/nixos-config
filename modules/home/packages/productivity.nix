{ config, lib, pkgs, isDarwin, ... }:

let
  cfg = config.rabit.home.packages.productivity;
in {
  options.rabit.home.packages.productivity.enable = lib.mkEnableOption "Enable home package set: Productivity";
  config = lib.mkIf cfg.enable {
    # Nix packages to install to $HOME
    #
    # Search for packages here: https://search.nixos.org/packages
    home.packages = with pkgs; [
      # File Management & Search
      fsearch
      syncthing
      syncthingtray
      localsend

      # Note Taking & Documentation
      siyuan
      # obsidian
      typora
      # pandoc

      # Development & Code Editors
      # vscode

      # Web Browsers & Download Tools
      # firefox
      microsoft-edge
      aria2

      # Office Suite
      wpsoffice-cn-fixup

      # Password Management
      keepassxc
      git-credential-keepassxc

      # Screenshot & Recording
      flameshot
      # asciinema_3
      obs-studio

      # Media Players
      vlc
      qmplay2

      # Networking
      daed
      v2rayn
      tail-tray

      # Remote Access
      rustdesk-flutter
      virt-viewer
      remmina
    ];

    # Add symlink for edge for Apps to work
    home.file = {
      ".local/bin/microsoft-edge-stable".source = "${pkgs.microsoft-edge}/bin/microsoft-edge";
    };

    programs.firefox.enable = true;
    programs.obsidian.enable = true;
    programs.pandoc.enable = true;
    programs.vscode.enable = true;

    programs.asciinema = {
      enable = true;
      package = pkgs.asciinema_3;
    };
  };
}
