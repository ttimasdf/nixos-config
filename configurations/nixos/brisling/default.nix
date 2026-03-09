# See /modules/nixos/* for actual settings
# This file is just *top-level* configuration.
{ flake, ... }:

let
  inherit (flake.inputs) self nur private-module;
in
{
  imports = [
    nur.modules.nixos.default
    self.nixosModules.common
    self.nixosModules.programs
    self.nixosModules.images
    private-module.nixosModules.all
    ./configuration.nix
  ];
}
