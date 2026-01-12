{ flake, config, lib, pkgs, ... }:

let
  inherit (flake.inputs) self;
in
{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  systemd.services.sshd.wantedBy = lib.mkForce ["multi-user.target"];
}