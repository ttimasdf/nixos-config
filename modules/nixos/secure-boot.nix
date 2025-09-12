{ flake, pkgs, lib, config, ... }:
let
  inherit (flake.inputs) self lanzaboote;
in
{
  imports = [
    lanzaboote.nixosModules.lanzaboote
  ];
  config = {
    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
    # systemd-boot is configured by lanzaboote
    boot.loader.systemd-boot.enable = lib.mkForce false;
  };
}
