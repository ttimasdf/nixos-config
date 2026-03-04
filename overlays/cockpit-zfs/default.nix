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

    # cockpit-zfs package overrides the patchPhase,
    # so we have to reapply the patchPhase from pkgs/stdenv/generic/setup.sh in postPatch.
    postPatch = ''
      local -a patchesArray
      concatTo patchesArray patches

      local -a flagsArray
      concatTo flagsArray patchFlags=-p1

      for i in "''${patchesArray[@]}"; do
          echo "applying patch $i"
          local uncompress=cat
          case "$i" in
              *.gz)
                  uncompress="gzip -d"
                  ;;
              *.bz2)
                  uncompress="bzip2 -d"
                  ;;
              *.xz)
                  uncompress="xz -d"
                  ;;
              *.lzma)
                  uncompress="lzma -d"
                  ;;
          esac

          # "2>&1" is a hack to make patch fail if the decompressor fails (nonexistent patch, etc.)
          # shellcheck disable=SC2086
          $uncompress < "$i" 2>&1 | patch "''${flagsArray[@]}"
      done
    '';
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
