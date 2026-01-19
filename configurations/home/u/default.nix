{ flake, config, lib, pkgs, isDarwin, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports =
    # Automatically imports everything else in the parent folder.
    (with builtins;
    map
      (fn: ./${fn})
      (filter (fn: fn != "default.nix") (attrNames (readDir ./.))))
    ++ [
      self.homeModules.default
    ];

  # Defined by /modules/home/options.nix
  # And used all around in /modules/home/*
  rabit.home.me = {
    username = "u";
    fullname = "ttimasdf";
    email = "opensource@rabit.pw";
    git.sshSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHbP5VCRKV5Q9AawX3C7CcIwXgnd9m8wvcrzrrpobrje Git commit signing for ttimasdf";
  };

  home.stateVersion = "24.11";
}
