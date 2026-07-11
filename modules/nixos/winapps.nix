{ flake, pkgs, lib, config, ... }:
let
  inherit (flake.inputs) self winapps;
in
{
  environment.systemPackages = [
    winapps.packages."${pkgs.stdenv.hostPlatform.system}".winapps
    winapps.packages."${pkgs.stdenv.hostPlatform.system}".winapps-launcher # optional
  ];
}
