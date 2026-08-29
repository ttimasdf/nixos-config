# PROJECT KNOWLEDGE BASE

**Generated:** 2026-05-09
**Commit:** f524e03
**Branch:** dev

## OVERVIEW
Multi-host NixOS flake with private module separation, reusable package inputs, and auto-wired outputs via nixos-unified. The `public-packages/` Git submodule is a workspace checkout of `ttimasdf/nix-packages`, the same repository consumed remotely by the `known-rabbit-packages` flake input.

## STRUCTURE
```
./
├── flake.nix             # Entry: nixos-unified autowiring, defines all inputs
├── configurations/       # Host & user configs (auto-discovered → flake outputs)
│   ├── nixos/<host>/     # → nixosConfigurations.<host>
│   ├── home/<user>/       # → legacyPackages.${system}.homeConfigurations.<user>
│   └── users/<user>.nix   # System-level user config (loaded by myusers.nix)
├── public-packages/      # Git submodule checkout of ttimasdf/nix-packages for authoring
├── packages/             # Packages local to this config, including private-source packages
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
| Add public package, overlay, or package module | `public-packages/` | Submodule checkout of `ttimasdf/nix-packages`; follow `public-packages/AGENTS.md` |
| Change the public package revision consumed here | `flake.lock` | Update the remote `known-rabbit-packages` input after pushing its repository |
| Add private-source package | `packages/<name>/default.nix` | Auto-discovered into this repository's local package overlay |
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

### Public Package Repository: Submodule vs Flake Input
The following names refer to the same upstream repository in different roles:

- `public-packages/` is the local Git submodule checkout used by humans and agents to author and test public packages, portable overlays, and package-specific NixOS modules.
- `ttimasdf/nix-packages` is the independently maintained and publishable upstream GitHub repository, intended for eventual NUR registration.
- `known-rabbit-packages` is this flake's remote input for that repository, declared in `flake.nix` and pinned independently in `flake.lock`.

The submodule is workspace-only: the root flake does not import `./public-packages`, and merely initializing or editing the submodule does not change Nix evaluation or the package revision consumed by this configuration. Builds use the locked `known-rabbit-packages` GitHub input. Keep the remote input rather than replacing it with a local `path:` input.

The submodule gitlink and `flake.lock` are recorded separately, but they must always point to the same commit. The `public-packages/` `HEAD` must equal `.locks.nodes["known-rabbit-packages"].locked.rev`; do not leave the workspace checkout ahead of or behind the flake input.

Synchronization is required in both directions:

- After `nix flake update` changes `known-rabbit-packages`, check out the new locked revision in `public-packages/` and commit the matching submodule pointer.
- After committing and pushing a new `public-packages` revision, run `nix flake update known-rabbit-packages` so `flake.lock` consumes that revision.

A public-package change is complete only when the package repository commit has been pushed, the flake input and submodule point to that same commit, and the parent repository contains the updated `flake.lock` and submodule pointer. Synchronize the submodule with the locked input using:

```bash
publicPackagesRev="$(nix flake metadata --json . | jq -r '.locks.nodes["known-rabbit-packages"].locked.rev')"
git -C public-packages fetch origin "$publicPackagesRev"
git -C public-packages checkout "$publicPackagesRev"
```

Verify the two revisions match with `git -C public-packages rev-parse HEAD` before evaluating, building, or committing.

This trusted reference configuration applies `known-rabbit-packages.overlays.all`, which composes every distinct public overlay. Hosts import published modules explicitly from `known-rabbit-packages.nixosModules`; `modules/nixos/programs/default.nix` only collects local custom program modules.

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
- **NEVER add public packages or overlays to the root `packages/` tree** - work in the `public-packages/` submodule and follow its `AGENTS.md`
- **ALWAYS keep `public-packages` synchronized with the locked `known-rabbit-packages` revision** - its `HEAD` must equal `.locks.nodes["known-rabbit-packages"].locked.rev`
- **NEVER assume a submodule update changes the flake input** - update `known-rabbit-packages` and commit `flake.lock` together with the matching submodule pointer
- **NEVER replace `known-rabbit-packages` with `path:./public-packages` for committed configuration** - the submodule is workspace-only
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

# Public-package workspace and input synchronization:
nix flake update known-rabbit-packages  # after pushing a public-packages commit
publicPackagesRev="$(nix flake metadata --json . | jq -r '.locks.nodes["known-rabbit-packages"].locked.rev')"
git -C public-packages fetch origin "$publicPackagesRev"
git -C public-packages checkout "$publicPackagesRev"
test "$(git -C public-packages rev-parse HEAD)" = "$publicPackagesRev"
```

## NOTES

- `currentSystem` is derived from `config.nixpkgs.hostPlatform.system` in `nixpkgs-overlays.nix`
- Home Manager configs exposed as `legacyPackages.${system}.homeConfigurations` (not `homeConfigurations`) due to pkgs dependency
- Public package and overlay authoring guidance lives in `public-packages/AGENTS.md`; the checkout is the `ttimasdf/nix-packages` repository
