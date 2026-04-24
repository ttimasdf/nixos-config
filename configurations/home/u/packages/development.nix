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

    # Git Hosting CLI
    gh
    glab
    forgejo-cli

    # Code Editors
    # vscode  # enabled by programs.vscode.enable
    antigravity
    # opencode
    # opencode-desktop
    # y-agent
    jetbrains.idea

    # Deployment tools
    coder
    terraform
  ];
  programs.vscode.enable = true;
}
