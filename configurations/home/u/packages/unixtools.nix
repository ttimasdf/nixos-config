{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # File and text utilities
    sd       # Intuitive find and replace tool
    tree     # Directory listing in tree format
    file     # File type identifier

    # System monitoring and process management
    pv       # Pipe viewer for monitoring data progress
    killall  # Kill processes by name
    ncdu     # Disk usage analyzer with ncurses interface
    hardinfo2 # System information and benchmarking tool

    # Development and build tools
    gnumake  # GNU Make build automation tool
    cmake
    gcc
    ninja
    just     # Modern command runner with justfile syntax
    nix-tree # Interactive Nix package browser
    nixfmt   # Nix code formatter
    android-tools # Android development and debugging tools

    # Network and remote access
    freerdp  # Remote Desktop Protocol client
    openssl  # Cryptography toolkit and SSL/TLS implementation
    proxychains-ng # Proxy tool for forcing TCP connections through proxies
    sshpass  # Non-interactive SSH password authentication

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
}
