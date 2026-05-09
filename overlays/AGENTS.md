# overlays/

## OVERVIEW
~15 Nixpkgs overlays with a **non-standard signature** that includes flake context. Auto-discovered and wired via nixos-unified.

## STRUCTURE
```
overlays/
├── <name>.nix              # Simple overlay → overlays.<name>
├── <name>/                 # Directory overlay (for patches, READMEs)
│   └── default.nix         # → overlays.<name>
├── overlay-template.md     # Full overlay examples & patterns
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Override package version | `overlays/<name>.nix` | `prev.foo.overrideAttrs (oldAttrs: { ... })` |
| Add patches to package | `overlays/<name>/patches/` + `rabit-lib.findPatches` | See cockpit-zfs, ark overlay dirs |
| Wrap binary with env vars | `overlays/wps.nix` | Example: fcitx fixup with `makeWrapper` |
| Scoped overrides (python, kde) | `overlays/overlay-template.md` | Uses `overrideScope` for nested pkg sets |
| Pinned nixpkgs version | `overlays/overlay-template.md` | Import from `flake.inputs.nixpkgs-stable` |

## CONVENTIONS

### MANDATORY Signature (NON-STANDARD)
```nix
{ flake, ... }:    # REQUIRED: gives access to flake.inputs (pinned nixpkgs, private-module, self)
final: prev:       # Standard overlay args
{ ... }
```
NOT standard `final: prev: { ... }` - won't work. `flake` arg passed by nixos-unified autowiring.

### Common Patterns
```nix
# Version override
foo = prev.foo.overrideAttrs (oldAttrs: rec {
  version = "X.Y.Z";
  src = prev.fetchFromGitHub {
    owner = "..."; repo = "..."; rev = "..."; hash = lib.fakeHash;
  };
});

# Adding build inputs / wraps
nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
postFixup = '' wrapProgram "$out/bin/foo" --set BAR "baz" '';

# Multiple patches
patches = (oldAttrs.patches or []) ++ (rabit-lib.findPatches ./patches);
```

### Accessing Flake Inputs
```nix
{ flake, ... }:
final: prev:
let
  pkgs-stable = import flake.inputs.nixpkgs-stable {
    system = prev.system;
    config.allowUnfree = true;
  };
  inherit (flake.inputs.self) rabit-lib;
in { ... }
```

## ANTI-PATTERNS

- **NEVER use `final: prev:` without `{ flake, ... }:` prefix** - won't work
- **NEVER forget `(oldAttrs.xxx or [])`** when appending to optional attributes
- **Do NOT define new packages here** - use `packages/` for new packages; overlays override existing ones
