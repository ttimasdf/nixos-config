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
    jetbrains.idea

    # AI Agentic Coding Tools
    antigravity
    # opencode
    # opencode-desktop
    # y-agent
    cc-switch

    openwarp
    qoder-cn
    bubblewrap  # needed by codex

    # Deployment tools
    # coder
    # terraform
  ];
  programs.vscode.enable = true;
}
