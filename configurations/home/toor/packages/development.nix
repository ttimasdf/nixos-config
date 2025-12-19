{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnumake  # GNU Make build automation tool
    cmake
    gcc
    ninja
    just     # Modern command runner with justfile syntax
    nix-tree # Interactive Nix package browser
    android-tools # Android development and debugging tools
    uv       # python runtime environment
    go       # golang runtime environment
    php      # php runtime environment
    # rustup # rust toolchains
    cargo    # rust package manager
    rustc    # rust compiler
  ];
}
