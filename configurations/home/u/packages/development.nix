{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python3
    uv

    # build tools
    gnumake  # GNU Make build automation tool
    cmake
    gcc
    ninja

    openssl  # Cryptography toolkit and SSL/TLS implementation

    # Code Editors
    # vscode  # enabled by programs.vscode.enable
    antigravity

  ];
  programs.vscode.enable = true;
}
