{ flake, ... }:

let
  inherit (flake.inputs) nur;
in
{
  imports = [
    nur.modules.nixos.default
  ];
}