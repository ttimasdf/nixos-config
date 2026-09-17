# The store paths an ISO has to carry on top of the host's runtime closure so
# that the system derivations regenerated from `hardware-configuration.nix` can
# still be built offline. See delta-build-inputs.py for the walk.
{
  pkgs,
  lib,
  # The packed host's system toplevel, e.g.
  # self.nixosConfigurations.<host>.config.system.build.toplevel.
  hostToplevel,
  # The generated system derivations that depend on hardware-configuration.nix,
  # as `.drvPath` strings (they carry store-path context, so they become inputs).
  deltaRoots,
  # Store paths the ISO carries beyond `hostToplevel` and `pkgs.stdenv`, e.g.
  # the baked flake and its inputs.
  packedPaths ? [ ],
}:
let
  # Real inputs, so that every `.drv` reachable from the roots is readable in
  # the build. `exportReferencesGraph` cannot be used for the graph itself: it
  # insists on every path it exports already being valid, and a build graph
  # references sources that were never realised (they are build-only).
  rootRefs = pkgs.linkFarm "iso-delta-roots" (
    lib.imap0 (i: path: {
      name = "root${toString i}";
      inherit path;
    }) deltaRoots
  );
in
pkgs.runCommand "iso-delta-build-inputs" {
  nativeBuildInputs = [ pkgs.python3 ];
  inherit rootRefs;
  passAsFile = [ "deltaRoots" ];
  inherit deltaRoots;
  # Only compared against, so listing the closures the ISO already carries is
  # enough -- and a derivation-valued root is accepted here.
  packedSet = pkgs.closureInfo {
    rootPaths = [ hostToplevel pkgs.stdenv ] ++ packedPaths;
  };
} ''
  python3 ${./delta-build-inputs.py} "$packedSet/store-paths" "$deltaRootsPath" > $out
''
