{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python3
    uv
    pnpm
    nodejs    # nodejs is included in pnpm closure, adding it does not add size
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

    openwarp
    qoder-cn
    bubblewrap

    # Deployment tools
    coder
    terraform
  ];
  programs.vscode.enable = true;
}
