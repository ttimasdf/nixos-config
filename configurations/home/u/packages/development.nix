{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python3
    uv
    pnpm
    nodejs    # nodejs is included in pnpm closure, adding it does not add size
    go
    # bun     # enabled by programs.bun.enable
    shellcheck

    # build tools
    gnumake
    cmake
    gcc
    ninja

    openssl
    android-tools

    # Git Hosting CLI
    # gh      # enabled by programs.gh.enable
    glab
    forgejo-cli

    # Code Editors
    # vscode  # enabled by programs.vscode.enable
    # jetbrains.idea

    # AI Agentic Coding Tools
    antigravity
    # opencode
    # opencode-desktop
    # y-agent
    cc-switch

    zap
    qoder-cn
    bubblewrap  # needed by codex

    # Deployment tools
    # terraform
    # coder

    # kubectl
    # kubectl-cnpg
    # kubectl-ktop
    # k9s
    # argocd
    # kubernetes-helm
    # kustomize
    # kubeseal
  ];
  programs.vscode.enable = true;
  programs.gh.enable = true;
  programs.bun.enable = true;
}
