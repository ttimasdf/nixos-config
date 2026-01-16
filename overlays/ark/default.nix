/**
  KDE Ark
  nixpkgs:
  https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/kde/gear/default.nix
  source:
  https://github.com/NixOS/nixpkgs/blob/5ae3b07d8d6527c42f17c876e404993199144b6a/pkgs/kde/generated/sources/gear.json#L72-L77
  https://github.com/KDE/ark/releases/tag/v25.08.3
 */
{ flake, ... }:

final: prev:
let
  inherit (flake.inputs.self) rabit-lib;
in
{
  kdePackages = prev.kdePackages.overrideScope (kdeFinal: kdePrev: {
    ark = kdePrev.ark.overrideAttrs (oldAttrs: {
      # git -C source/ark format-patch -o ../../overlays/ark/patches 25.08.3..feat-cli7z
      patches = (oldAttrs.patches or []) ++ (rabit-lib.findPatches ./patches);
    });
  });
}
