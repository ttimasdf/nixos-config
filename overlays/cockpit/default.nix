/**
  Cockpit overlay to patch py-libzfs with FreeBSD compatibility fixes

  This overlay patches the py-libzfs package used by cockpit-zfs to fix
  build issues on FreeBSD stable/13 and stable/14.

  PR: https://github.com/truenas/py-libzfs/pull/308

  Original package:
  https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/py-libzfs/default.nix
*/
{ flake, ... }:

final: prev:
{
  python3Packages = prev.python3Packages.overrideScope (pyFinal: pyPrev: {
    py-libzfs = pyPrev.py-libzfs.overrideAttrs (oldAttrs: {
      name = final.lib.trace oldAttrs.name + "-patched";
      patches = (oldAttrs.patches or []) ++ [
        (final.fetchpatch2 {
          url = "https://github.com/truenas/py-libzfs/pull/308.patch";
          hash = final.lib.fakeHash;
        })
      ];
    });
  });
}
