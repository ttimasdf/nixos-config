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
├── private/              # Gitignored clone of ttimasdf/nixos-config-private
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
| Add private-source package | `private/packages/<name>/` | Gitignored clone of `ttimasdf/nixos-config-private` |
| Add private overlay | `private/overlays/` | Gitignored clone of `ttimasdf/nixos-config-private` |
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

### Public Package Submodule Workflow
Most package and overlay changes belong in the `public-packages/` submodule. Make
those changes inside the submodule, then commit and push the submodule first.
The parent flake consumes the pushed GitHub revision through the
`known-rabbit-packages` input; it does not import `./public-packages` directly.

After pushing the submodule commit, update the parent flake input to that exact
commit, verify it works, and commit the lockfile and submodule pointer together:

```bash
# From the public-packages repository:
git -C public-packages add <files>
git -C public-packages commit
git -C public-packages push origin HEAD

# From the parent repository:
nix flake update known-rabbit-packages
publicPackagesRev="$(nix flake metadata --json . | jq -r '.locks.nodes["known-rabbit-packages"].locked.rev')"
publicPackagesHead="$(git -C public-packages rev-parse HEAD)"
test "$publicPackagesHead" = "$publicPackagesRev"
nix flake check

git add flake.lock public-packages
git commit -m "build(public-packages): update package revision"
```

Never replace the remote input with `path:./public-packages`, commit the parent
submodule pointer before updating `flake.lock`, or leave the submodule and
`known-rabbit-packages` locked revision out of sync.

This trusted reference configuration applies `known-rabbit-packages.overlays.all`, which composes every distinct public overlay. Hosts import published modules explicitly from `known-rabbit-packages.nixosModules`; `modules/nixos/programs/default.nix` only collects local custom program modules.

### Private Packages and Overlays
`private/` is a gitignored local clone of
`https://github.com/ttimasdf/nixos-config-private.git`. Private packages and
overlays belong in `private/packages/` and `private/overlays/`, respectively.
Commit and push private changes in that repository; they are not recorded in
this parent repository. Do not add private-source software to the public
`public-packages/` repository.

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
- **Public packages and overlays belong in `public-packages/`**; private packages and overlays belong in `private/`.
- **Keep the submodule and locked `known-rabbit-packages` revision equal**; update and commit `flake.lock` and the submodule pointer together.
- **Never replace `known-rabbit-packages` with `path:./public-packages`**; the submodule is workspace-only.
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

# Public-package synchronization is documented in
# `### Public Package Submodule Workflow` above.
```

## NOTES

- `currentSystem` is derived from `config.nixpkgs.hostPlatform.system` in `nixpkgs-overlays.nix`
- Home Manager configs exposed as `legacyPackages.${system}.homeConfigurations` (not `homeConfigurations`) due to pkgs dependency
- Public package and overlay authoring guidance lives in `public-packages/AGENTS.md`; private package and overlay guidance lives in `private/`
