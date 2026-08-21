{ flake, ... }:
let
  inherit (flake.inputs) rabit-nix-packages;
in
{
  imports = builtins.attrValues rabit-nix-packages.nixosModules;
}
