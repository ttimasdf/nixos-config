{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # File Management & Search
    fsearch
    syncthing
    syncthingtray
    localsend

    # Note Taking & Documentation
    siyuan
    obsidian
    typora
    # pandoc

    # Development & Code Editors
    # vscode

    # Web Browsers & Download Tools
    # firefox
    microsoft-edge
    aria2

    # Office Suite
    wpsoffice-cn

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
  # programs.obsidian.enable = true;
  programs.pandoc.enable = true;
  programs.vscode.enable = true;

  programs.asciinema = {
    enable = true;
    package = pkgs.asciinema_3;
  };
}
