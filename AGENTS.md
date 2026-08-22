# PROJECT KNOWLEDGE BASE

**Generated:** 2026-05-09
**Commit:** f524e03
**Branch:** dev

## OVERVIEW
Multi-host NixOS flake with private module separation, reusable package inputs, and auto-wired outputs via nixos-unified.

## STRUCTURE
```
./
├── flake.nix             # Entry: nixos-unified autowiring, defines all inputs
├── configurations/       # Host & user configs (auto-discovered → flake outputs)
│   ├── nixos/<host>/     # → nixosConfigurations.<host>
│   ├── home/<user>/       # → legacyPackages.${system}.homeConfigurations.<user>
│   └── users/<user>.nix   # System-level user config (loaded by myusers.nix)
├── packages/             # Local/private-source packages only
├── modules/
│   ├── nixos/            # NixOS modules (→ nixosModules)
│   ├── home/             # Home Manager modules
│   └── flake/            # Flake modules + custom lib (rabit-lib)
├── scripts/              # Pre-commit hooks, nix-store helpers
└── README.md             # xc task definitions, full structure docs
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add public package or overlay | `../nix-packages/` | Published through the `known-rabbit-packages` input |
| Add private-source package | `packages/<name>/default.nix` | Auto-discovered into the local package overlay |
| Add NixOS system module | `modules/nixos/<name>.nix` | Auto-wired to `nixosModules.<name>` |
| Add Home Manager module | `modules/home/<name>.nix` | Import via `modules/home/all.nix` |
| Add flake/dev utility | `modules/flake/<name>.nix` | Add helper to `modules/flake/lib.nix` |
| Host-specific config | `configurations/nixos/<host>/configuration.nix` | Hardware config in same dir |
| User home config | `configurations/home/<user>/default.nix` | Auto-discovered for myusers |
| Build commands | README.md `## Tasks` section | `xc <task>` runner |
| Flake inputs | `flake.nix` lines 5-62 | Includes nixos-unified, home-manager, lanzaboote, etc. |
| Source hashes | Use `lib.fakeHash` placeholder | Replace with real hash after first build |
| Patch collection | Use `rabit-lib.findPatches ./patches` | Auto-discovers all .patch files in directory |

## CONVENTIONS

### Reusable Packages and Overlays
Public packages, portable overlays, and package-specific NixOS modules live in `ttimasdf/nix-packages`. This trusted reference configuration consumes `known-rabbit-packages.overlays.all`, which composes every distinct public overlay automatically. Hosts import published modules explicitly from `known-rabbit-packages.nixosModules`; `modules/nixos/programs/default.nix` only collects local custom program modules.

### Local Package Auto-Discovery
The remaining `packages/` tree is reserved for packages that cannot be published, such as private-source packages. Direct children are discovered with `rabit-lib.forAllNixFiles`.

### Configuration Auto-Wiring
Uses nixos-unified autowiring. Directory structure maps directly to flake outputs. No manual listing in `flake.nix` needed.

### callPackage Pattern
All packages are called via `lib.callPackageWith final fn { }` in `modules/nixos/common/nixpkgs-overlays.nix`. Pass extra args as second parameter.

### Formatter
Uses `nix fmt` → treefmt with nixfmt, statix, deadnix, nixf-diagnose, keep-sorted. Config in home-manager/treefmt.toml.

### Host Config Signature
```nix
{ flake, config, lib, pkgs, ... }:
let inherit (flake.inputs) self; in
{ imports = [ ./hardware-configuration.nix ]; ... }
```

## ANTI-PATTERNS (THIS PROJECT)

- **NEVER change bootloader UUID** after initial install (viscacha:508, MNIX:501)
- **NEVER put NixOS-specific config in `configurations/nixos/common/`** - shared between nixos and nix-darwin
- **NEVER add public packages or overlays here** - use the `nix-packages` repository
- **NEVER create nested local packages** - `forAllNixFiles` does not recurse
- **NEVER leave `nixos-version-hint.txt` empty or "changeme"** - build will fail
- **Deprecated**: `xc trim-generations` → use `xc clean` instead

## UNIQUE STYLES

- **Version hint**: `nixos-version-hint.txt` appended to boot menu labels; pre-commit hook validates it's staged with .nix changes
- **User auto-discovery**: `modules/nixos/common/myusers.nix` discovers users from `configurations/home/` → auto-configures system users
- **xc task runner**: All dev commands defined as xc tasks in README.md
- **Custom `rabit` namespace**: Project-specific options under `rabit.nixos.*` and `rabit.home.*`

## COMMANDS

```bash
xc update          # nix flake update
xc build           # nh os switch (build + activate + boot default)
xc test            # nh os build (build only, don't activate)
xc check           # git add . && nix flake check
xc lint            # nix fmt
xc clean           # nh clean all
xc dev             # nix develop
xc build-xfce-iso  # Build savior rescue ISO
xc build-nas-vm    # Build basenji Proxmox image
xc list            # List system generations
xc pre-commit-hook # Install version-hint pre-commit hook

# In devshell:
nixos-eval-config <host> <option>  # Evaluate NixOS config option

# Package devshell:
nix develop .#<package-name>
nix develop .#nixosConfigurations.<host>.pkgs.<package>
```

## NOTES

- `currentSystem` is derived from `config.nixpkgs.hostPlatform.system` in `nixpkgs-overlays.nix`
- Home Manager configs exposed as `legacyPackages.${system}.homeConfigurations` (not `homeConfigurations`) due to pkgs dependency
- Public package and overlay authoring guidance lives in the `nix-packages` repository
