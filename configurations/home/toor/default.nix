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

  # Defined by /modules/home/me.nix
  # And used all around in /modules/home/*
  rabit.home.me = {
    username = "toor";
    fullname = "toor";
    email = "milktea@vmoe.info";
  };

  home.sessionPath = [
    "$HOME/.cargo/bin"
  ];

  home.stateVersion = "24.11";
}
