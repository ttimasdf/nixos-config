{ flake, pkgs, lib, config, ... }:
let
  inherit (flake.inputs) self winapps;
in
{
  environment.systemPackages = [
    winapps.packages."${pkgs.system}".winapps
    winapps.packages."${pkgs.system}".winapps-launcher # optional
  ];
}
