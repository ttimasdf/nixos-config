{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python3
    uv

    # Development & Code Editors
    # vscode  # enabled by programs.vscode.enable
    antigravity

  ];
  programs.vscode.enable = true;
}
