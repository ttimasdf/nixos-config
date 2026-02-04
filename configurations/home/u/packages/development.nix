{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python3
    uv

    # build tools
    gnumake
    cmake
    gcc
    ninja

    openssl
    android-tools

    # Code Editors
    # vscode  # enabled by programs.vscode.enable
    antigravity

  ];
  programs.vscode.enable = true;
}
