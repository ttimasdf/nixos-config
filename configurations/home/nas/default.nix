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
      self.homeModules.all
    ];

  # Defined by /modules/home/options.nix
  # And used all around in /modules/home/*
  rabit.home.me = {
    username = "nas";
    fullname = "NAS Admin";
    email = "nas@basenji.local";
  };

  home.stateVersion = "25.05";
}
