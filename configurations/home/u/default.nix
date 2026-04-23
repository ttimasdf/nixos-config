{ flake, config, lib, pkgs, isDarwin, ... }:
let
  inherit (flake.inputs) self private-module;
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
      private-module.homeModules.all
    ];

  # Defined by /modules/home/options.nix
  # And used all around in /modules/home/*
  rabit.home.me = {
    username = "u";
    fullname = "ttimasdf";
    email = "opensource@rabit.pw";
    git.sshSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHbP5VCRKV5Q9AawX3C7CcIwXgnd9m8wvcrzrrpobrje Git commit signing for ttimasdf";
  };

  home.sessionVariables = {
    # disable telemetry for oh-my-openagent
    OMO_SEND_ANONYMOUS_TELEMETRY = "0";
  };

  home.stateVersion = "24.11";
}
