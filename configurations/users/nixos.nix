{ flake, pkgs, lib, config, ... }:

{
  # set users.users.<name> options here
  # https://search.nixos.org/options?channel=unstable&query=users.users
  extraGroups = [
    "wheel"       # Enable 'sudo' for the user.
  ];

  openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE9Ku7hnkhgSlD03OXFjdBWmQ78SMDjVu5pqGTgLWT0A testkey"
  ];
} // lib.optionalAttrs config.programs.zsh.enable {
  shell = pkgs.zsh;
}
