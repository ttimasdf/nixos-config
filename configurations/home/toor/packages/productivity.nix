{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # File Management & Search
    fsearch
    localsend

    # Note Taking & Documentation
    siyuan
    obsidian
    typora
    # pandoc

    # Development & Code Editors
    # vscode
    antigravity
    appimage-run

    # Web Browsers & Download Tools
    # firefox  # enabled below
    # microsoft-edge
    aria2

    # Office Suite
    wpsoffice-cn-fcitx
    # cherry-studio
    # lmstudio
    gimp
    # dvdplusrwtools

    # Password Management
    # keepassxc
    # git-credential-keepassxc
    bitwarden-desktop

    # Screenshot & Recording
    # flameshot
    snipaste
    # asciinema_3
    obs-studio

    # Media Players
    vlc
    mpv
    qmplay2
    ffmpeg

    # Networking
    # daed
    v2rayn
    tail-tray
    clash-verge-rev

    # Remote Access
    # rustdesk-flutter
    virt-viewer
    remmina
    winbox4
    putty
  ];

  # Add symlink for edge for Apps to work
  # home.file = {
  #   ".local/bin/microsoft-edge-stable".source = "${pkgs.microsoft-edge}/bin/microsoft-edge";
  # };

  programs.firefox.enable = true;
  programs.chromium.enable = true;
  programs.pandoc.enable = true;
  programs.vscode.enable = true;

  programs.asciinema = {
    enable = true;
    package = pkgs.asciinema_3;
  };
}
