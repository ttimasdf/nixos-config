{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # File and text utilities
    sd       # Intuitive find and replace tool
    tree     # Directory listing in tree format
    file     # File type identifier
    pv       # Pipe viewer for monitoring data progress

    # System monitoring and process management
    killall  # Kill processes by name
    ncdu     # Disk usage analyzer with ncurses interface
    nix-tree # Interactive Nix package browser
    nvtopPackages.nvidia  # NVIDIA GPU monitoring tool

    # Miscellaneous utilities
    ascii    # ASCII table and character reference
    kdiff3   # Diff and merge tool for files and directories
  ];

  # Programs natively supported by home-manager.
  # They can be configured in `programs.*` instead of using home.packages.
  programs.bat.enable = true;   # Better `cat` with syntax highlighting
  programs.fzf.enable = true;   # Fuzzy finder for files and history
  programs.jq.enable = true;    # JSON processor for command-line
  programs.btop.enable = true;  # System monitor with resource graphs
  programs.tmate.enable = true; # Terminal sharing for collaboration
  programs.ripgrep.enable = true; # Fast text search tool
  programs.fd.enable = true;    # Simple and fast file finder
  programs.yazi = {
    enable = true;
    package = pkgs.yazi.override { _7zz = pkgs._7zz-nls; };
    shellWrapperName = "yy";
  };
}
