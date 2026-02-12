{ flake, pkgs, lib, config, ... }:

{
  # set users.users.<name> options here
  # https://search.nixos.org/options?channel=unstable&query=users.users

  extraGroups = [
    "wheel"       # Enable 'sudo' for the user.
    "networkmanager" # Network management
    "podman"      # Container management
    "storage"     # Storage management
  ];
}
