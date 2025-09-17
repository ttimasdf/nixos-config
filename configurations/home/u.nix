{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    self.homeModules.default
  ];

  # Defined by /modules/home/me.nix
  # And used all around in /modules/home/*
  me = {
    username = "u";
    fullname = "ttimasdf";
    email = "opensource@rabit.pw";
  };

  rabit.home.packages.productivity.enable = true;
  rabit.home.packages.unixtools.enable = true;
  rabit.home.packages.pentest.enable = true;

  home.stateVersion = "24.11";
}
