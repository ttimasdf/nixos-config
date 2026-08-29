---
name: nix-overlay-writer
description: Help write Nixpkgs overlays for this nixos-config repository. Use this skill whenever the user asks to override, patch, pin, wrap, replace, or customize an existing Nixpkgs package under overlays/, including scoped package sets such as kdePackages, qt6Packages, python packages, or packages imported from pinned nixpkgs inputs. This skill is specifically for overlays and existing package overrides; if the user wants a brand-new derivation under packages/, use nix-package-writer instead.
---

# Nix Overlay Writer

Use this skill to add or repair Nixpkgs overlays in this repository's `overlays/` tree. The repo auto-discovers overlays, so the main job is to write a correct override that follows local wiring and avoids generic Nix overlay assumptions.

## Scope

This skill covers existing-package customization only:

- `overlays/<name>.nix`
- `overlays/<name>/default.nix`
- supporting files inside an overlay directory, such as `patches/*.patch`
- overrides for nested package sets like `kdePackages`, `qt6Packages`, `python3Packages`, or interpreter-specific Python package sets
- importing packages from a pinned Nixpkgs input or tarball for compatibility work

Do not use this skill to create new standalone package definitions under `packages/`. If the user asks to package new software from source or make a new derivation available as `pkgs.<name>`, use `nix-package-writer` instead.

## First steps

1. Read `overlays/AGENTS.md` and any overlay examples that match the requested pattern.
2. Inspect the target package in current `nixpkgs` when you need to know attribute names, phases, or nested package-set structure. Do not guess `overrideAttrs` fields from memory.
3. Choose a file layout:
   - Use `overlays/<name>.nix` for simple one-file overrides.
   - Use `overlays/<name>/default.nix` when patches, notes, or helper files need to live beside the overlay.
4. Check whether this is really an overlay. Overlays are for changing or exposing existing package attributes; new derivations belong in `packages/`.

## Repository conventions

Every overlay must use this repository's non-standard flake-aware signature:

```nix
{ flake, ... }:

final: prev:
{
  # overrides
}
```

Do not write the generic `final: prev: { ... }` form by itself. These overlays are auto-wired through nixos-unified and receive `flake` so they can access `flake.inputs`, `flake.inputs.self.rabit-lib`, and pinned inputs.

All `.nix` files directly under `overlays/` and directories with `default.nix` are auto-discovered. Do not edit `flake.nix` or manually register the overlay.

Prefer these references before editing:

- `overlays/AGENTS.md` for current project conventions.
- `overlays/overlay-template.md` for scoped overrides and pinned nixpkgs examples.
- `.clinerules/writing-nix-config.md` only as older background guidance.
- Existing overlays such as `clash-verge-rev.nix`, `podman-compose.nix`, `wps.nix`, `zip-nls.nix`, `unzip-nls.nix`, `qt68.nix`, and `cockpit-zfs/default.nix` for local style.

## Common patterns

### Version or source pin

Use `prev.<pkg>.overrideAttrs` and keep the output attribute name aligned with the package users will install. Use `final.lib` as `lib` when needed.

```nix
{ flake, ... }:

final: prev:
let
  lib = final.lib;
in
{
  example = prev.example.overrideAttrs (oldAttrs: rec {
    version = "1.2.3";
    src = lib.trace "FYI: example pinned to ${version}" prev.fetchFromGitHub {
      owner = "owner";
      repo = "example";
      tag = "v${version}";
      hash = lib.fakeHash;
    };
  });
}
```

Use `lib.fakeHash` for new or changed source and patch hashes, build once, then replace it with the real hash from the Nix error. Keep trace messages when a package is intentionally pinned so future rebuilds show why the version differs from upstream nixpkgs.

### Append attributes safely

Many package attributes are optional. When adding dependencies, patches, hooks, or wrappers, preserve existing values and use `or []` unless you have verified the attribute is always present.

```nix
nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
buildInputs = (oldAttrs.buildInputs or []) ++ [ prev.libayatana-appindicator ];
patches = (oldAttrs.patches or []) ++ [
  (prev.fetchpatch {
    url = "https://example.com/fix.patch";
    hash = lib.fakeHash;
  })
];
```

### Local patch directories

Use an overlay directory when maintaining one or more local patches. The repository exposes `rabit-lib.findPatches` from `flake.inputs.self`.

```nix
{ flake, ... }:

final: prev:
let
  inherit (flake.inputs.self) rabit-lib;
in
{
  example = prev.example.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or []) ++ (rabit-lib.findPatches ./patches);
  });
}
```

Put patches under `overlays/<name>/patches/`. Do not hard-code a list when the intent is to apply every patch in that directory.

### Wrapping binaries

When wrapping executables, append `prev.makeWrapper` to `nativeBuildInputs` and add a targeted `postFixup` or `postInstall`. Preserve existing hooks when overriding a phase wholesale.

```nix
nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
postFixup = (oldAttrs.postFixup or "") + ''
  for prog in $out/bin/foo $out/bin/bar; do
    if [ -f "$prog" ]; then
      wrapProgram "$prog" --set SOME_ENV value
    fi
  done
'';
```

Use wrappers for runtime environment fixes, flags, input methods, library paths, or compatibility shims. Avoid broad loops over every binary unless the existing package pattern justifies it.

### Scoped package-set overrides

When overriding nested sets, override the set rather than creating an unrelated top-level attribute. Name the inner final/prev pair so readers do not confuse it with the outer overlay arguments.

```nix
{ flake, ... }:

final: prev:
{
  kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
    ark = kprev.ark.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or []) ++ [ ./fix.patch ];
    });
  });
}
```

For Python interpreters, use the interpreter's package override mechanism and return Python modules through the relevant Python package set. Be explicit when the nested `final`/`prev` belong to Python, not top-level nixpkgs.

### Pinned nixpkgs imports

Use pinned nixpkgs only when a package must come from another nixpkgs revision or input. Prefer an existing flake input over ad hoc tarballs when available.

```nix
{ flake, ... }:

final: prev:
let
  pkgsStable = import flake.inputs.nixpkgs-stable {
    system = prev.system;
    config.allowUnfree = true;
  };
in
{
  example = pkgsStable.example;
}
```

If importing from `fetchTarball`, use a descriptive `name`, pin the archive hash, and explain why the pin exists. Do not import a second nixpkgs just to avoid writing a small `overrideAttrs`.

## Validation workflow

Use the narrowest validation that proves the overlay works:

1. Format with `nix fmt` or the repo's `xc lint` task when available.
2. Evaluate the exposed attribute with `nix eval` or `nix repl` style checks if the change is structural.
3. Build the affected package, for example `nix build .#nixosConfigurations.<host>.pkgs.<attr>` or the host-specific command used elsewhere in the repo.
4. For source or patch hash changes, replace `lib.fakeHash` after the first failing build and rebuild.
5. If the overlay affects a host package selection, run the relevant host build command such as `xc test` if practical.

Do not claim the overlay works until the target attribute evaluates or builds. If full builds are too expensive, report exactly which narrower checks passed and what remains unverified.

## Review checklist

Before finishing, verify:

- The overlay starts with `{ flake, ... }:` followed by `final: prev:`.
- The file is directly under `overlays/` or is `overlays/<name>/default.nix`.
- Existing package attributes are preserved with `(oldAttrs.<field> or [])` or `(oldAttrs.<field> or "")` when appending.
- New hashes use `lib.fakeHash` only temporarily and are replaced after a build when possible.
- Local patch directories use `rabit-lib.findPatches ./patches`.
- Scoped packages are overridden through their package set, not by creating a misleading top-level attribute.
- The change does not belong in `packages/` instead.
- No unrelated overlays, host configs, or package definitions were changed.
