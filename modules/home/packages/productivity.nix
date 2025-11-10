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
      # File Management
      fsearch
      syncthing
      syncthingtray
      localsend

      # Note Taking
      siyuan
      obsidian
      typora
      pandoc

      # Productivity
      vscode
      microsoft-edge
      wpsoffice-cn-fixup
      keepassxc
      git-credential-keepassxc
      aria2

      # Screen Recording
      flameshot
      asciinema_3
      obs-studio

      # Media Playback
      vlc
      qmplay2

      # Networks
      daed
      v2rayn
      tail-tray

      # Remote Management
      rustdesk-flutter
      virt-viewer
      remmina
    ];

    # Add symlink for edge for Apps to work
    home.file = {
      ".local/bin/microsoft-edge-stable".source = "${pkgs.microsoft-edge}/bin/microsoft-edge";
    };

    programs.firefox.enable = true;
  };
}
