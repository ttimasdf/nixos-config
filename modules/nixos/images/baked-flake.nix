{ flake, pkgs, lib }:
# Everything needed to bake the flake onto the ISO so a host can be evaluated
# and built with no network access.
let
  inherit (flake) self;

  # The flake source plus every source reachable in its input graph. Flake
  # inputs expose their own `inputs`, so this walks transitive inputs too;
  # dedup by store path also breaks the input cycle. ~0.2 GiB, dominated by
  # the nixpkgs source.
  flakeInputPaths =
    let
      walk = seen: node:
        let
          path = node.outPath or null;
          isNew = path == null || !(builtins.elem path seen);
          seen' = if path == null then seen else seen ++ [ path ];
        in
        if isNew then builtins.foldl' walk seen' (builtins.attrValues (node.inputs or { })) else seen;
    in
    walk [ ] { inputs = flake.inputs; };

  # Inputs overridden on the command line are path inputs and are the only ones
  # the installer may replay with --override-input. A git input carries `rev`
  # and `lastModified`; replaying it as `path:` would strip them, and nixpkgs
  # would then report `26.11.19700101.dirty` instead of its real revision --
  # producing a different system closure than the one packed into the ISO, so
  # nothing could be substituted from the ISO store.
  flakeInputManifest = lib.mapAttrs (_: input: input.outPath)
    (lib.filterAttrs (_: input: (input.rev or null) == null) (builtins.removeAttrs flake.inputs [ "self" ]));

  # A filtered snapshot of the flake source to bake onto the ISO. Drops VCS and
  # build junk via cleanSourceFilter (including `.git` and `result`), plus the
  # private checkout, the public-packages submodule, generated artifacts and
  # editor caches. The installer copies this to the target, so it should hold
  # only what evaluation needs.
  flakeSource = lib.cleanSourceWith {
    name = "nixos-config-source";
    src = self;
    filter =
      path: type:
      let
        base = baseNameOf (toString path);
      in
      lib.cleanSourceFilter path type
      && !(builtins.elem base [
        ".direnv"
        ".ruff_cache"
        ".vscode"
        "__pycache__"
        "nix-paths.txt"
        "private"
        "public-packages"
        "source"
        "viscacha-tree.html"
      ]);
  };

  # <input> <store-path> lines, consumed by nixos-rabit-install to pin the
  # overridden inputs of the baked flake. Lives in the store, not /etc.
  flakeInputManifestFile = pkgs.writeText "nixos-config-inputs"
    (lib.concatStringsSep "\n" (lib.mapAttrsToList (name: path: "${name} ${path}") flakeInputManifest) + "\n");

  # The store contents every installer-capable ISO preloads.
  offlineFlakeStoreContents = lib.unique ([ flakeSource ] ++ flakeInputPaths);

  # The installer preconfigured for the live ISO. It carries the baked flake
  # source and the input manifest (both plain store paths) via environment
  # variables and delegates to the generic package.
  nixosRabitInstall = pkgs.writeShellApplication {
    name = "nixos-rabit-install";
    text = ''
      export RABIT_ISO_BAKED_FLAKE=${flakeSource}
      export RABIT_ISO_BAKED_INPUTS=${flakeInputManifestFile}
      exec ${pkgs."nixos-rabit-install"}/bin/nixos-rabit-install "$@"
    '';
  };
in
{
  inherit
    flakeSource
    flakeInputManifest
    flakeInputManifestFile
    offlineFlakeStoreContents
    nixosRabitInstall
    ;
}
