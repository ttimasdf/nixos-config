# apps-01 — application container host (unprivileged NixOS LXC). Appliance wiring.
{ flake, ... }:

let
  inherit (flake.inputs) self private-module known-rabbit-packages;
in
{
  imports = [
    self.nixosModules.common
    private-module.nixosModules.all
    ./configuration.nix
  ];

  # known-rabbit-packages: overlay brings pkgs.easytier-bin (release binaries)
  # among other personal packages.
  nixpkgs.overlays = [ known-rabbit-packages.overlays.default ];
}
