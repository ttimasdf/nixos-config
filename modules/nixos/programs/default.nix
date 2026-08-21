{ flake, ... }:
let
  inherit (flake.inputs) nix-packages;
in
{
  imports = builtins.attrValues nix-packages.nixosModules;
}
