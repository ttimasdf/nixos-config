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
      # Productivity apps
      cherry-studio
      fsearch
      syncthing
      syncthingtray
      siyuan
      obsidian
      vscode
      microsoft-edge
      vlc
      keepassxc
      git-credential-keepassxc
      wpsoffice-cn
      localsend
      aria2
      typora
      pandoc
      flameshot
      asciinema_3

      clash-verge-rev
      daed
      v2rayn
    ];

    programs.firefox.enable = true;
  };
}
