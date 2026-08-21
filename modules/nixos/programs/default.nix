{ flake, ... }:
let
  inherit (flake.inputs) known-rabbit-packages;
in
{
  imports = builtins.attrValues known-rabbit-packages.nixosModules;
}
