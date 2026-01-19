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

  # Defined by /modules/home/home-options.nix
  # And used all around in /modules/home/*
  rabit.home.me = {
    username = "nixos";
    fullname = "NixOS LiveCD User";
    email = "livecd@nixos.org";
  };

  home.stateVersion = "24.11";
}
