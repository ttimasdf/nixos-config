# See /modules/nixos/* for actual settings
# This file is just *top-level* configuration.
{ flake, ... }:

let
  inherit (flake.inputs) self nur;
in
{
  imports = [
    nur.modules.nixos.default
    self.nixosModules.common
    self.nixosModules.hosts
    self.nixosModules.programs
    self.nixosModules.nixos-generators
    ./configuration.nix
  ];
}
