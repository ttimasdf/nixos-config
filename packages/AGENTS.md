# packages/

## OVERVIEW
29+ custom packages, auto-discovered via `forAllNixFiles` and wired into `pkgs.*`.

## STRUCTURE
```
packages/
├── <name>.nix             # Single-file package → pkgs.<name>
├── <name>/                # Directory package (for patches, scripts, etc.)
│   └── default.nix        # → pkgs.<name>
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add new package | Create `packages/<name>.nix` or `packages/<name>/default.nix` | Auto-discovered, no flake.nix edit needed |
| Package devshell | `nix develop .#<name>` | Run build phases with `runPhase <phase>` |
| Debugging build | `packages/binaryninja/` example | Has devshell.sh, repack.sh, releases.json |

## CONVENTIONS

### Package Definition Pattern
```nix
{ lib, stdenv, fetchurl, ... }:    # callPackage args, one per line

stdenv.mkDerivation {
  pname = "my-package";
  version = "1.0.0";
  src = fetchurl { ... };
  meta = {
    description = "...";
    homepage = "...";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
```

### How Packages Are Wired
`modules/nixos/common/nixpkgs-overlays.nix` calls:
```nix
rabit-lib.forAllNixFiles "${self}/packages"
  (fn: lib.callPackageWith final fn { });
```
This auto-adds every package to `pkgs.*`. No manual listing needed.

### Directory vs Single-File
- Use **single-file** when package is self-contained
- Use **directory** when you need extra files (patches, update scripts, helper .nix files)

### Source Hashes
- Use `lib.fakeHash` as placeholder for new sources
- Replace with real hash (from build error or `nix-prefetch-url`) after first attempt

### AppImage Packages
Common pattern: `appimageTools.extractType2` + `appimageTools.wrapType2`. See `packages/hyper/`, `packages/yakit/`.

## ANTI-PATTERNS

- **NEVER create nested packages** (`packages/foo/bar/default.nix`) - `forAllNixFiles` does NOT recurse
- **Do NOT use `rec` in package definitions** - prefer `finalAttrs` pattern when self-referencing needed
