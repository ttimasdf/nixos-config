{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python3
    uv
    pnpm
    # bun     # bun is installed from prebuilt binary.

    # build tools
    gnumake
    cmake
    gcc
    ninja

    openssl
    android-tools
    gh

    # Code Editors
    # vscode  # enabled by programs.vscode.enable
    antigravity

  ];
  programs.vscode.enable = true;
}
