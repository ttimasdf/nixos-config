/**
  Cockpit overlay to remove 45Drives branding from cockpit-zfs

  This overlay patches cockpit-zfs to remove vendor branding from the web interface:
  - Changes "45Drives ZFS" to "ZFS" in the Cockpit menu label
  - Removes the 45Drives logo from the HoustonHeader component

  Original package:
  https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/co/cockpit-zfs/package.nix
*/
{ flake, ... }:

final: prev:
let
  inherit (flake.inputs.self) rabit-lib;
in
{
  cockpit-zfs = prev.cockpit-zfs.overrideAttrs (oldAttrs: {
    pname = oldAttrs.pname + "-patched";
    patches = (oldAttrs.patches or []) ++ (rabit-lib.findPatches ./patches);
  });

  # python312Packages = prev.python312Packages.overrideScope (pyFinal: pyPrev: {
  #   py-libzfs = pyPrev.py-libzfs.overrideAttrs (oldAttrs: {
  #     name = oldAttrs.name + "-patched";
  #     patches = (oldAttrs.patches or []) ++ [
  #       (final.fetchpatch2 {
  #         url = "https://github.com/truenas/py-libzfs/pull/308.patch";
  #         hash = "sha256-Bk4e6E4b6BuKJeQ+f51ug3ILfpG0rBzYsJT5BKzlvWc=";
  #       })
  #     ];
  #   });
  # });
}
