[![xc compatible](https://xcfile.dev/badge.svg)](https://xcfile.dev)

# KnownRabbit NixOS Config

A modular, multi-host NixOS configuration with private module support so you can ditch agenix.

## Hosts

- **viscacha**: Personal config for [@ttimasdf](https://github.com/ttimasdf)
- **MNIX**: Personal config for [@Tardis07](https://github.com/Tardis07)
- **savior**: Minimal config for building ISOs (system rescue & benchmarking)
- **basenji**: NAS virtual machine with ZFS storage, Cockpit web management, Samba file sharing, and Podman containers

## Features

- **Version Hints**: Custom suffixes for system version numbers in boot menus and ISO filenames.
- **Private Module**: Supports separation of public and private configuration via a private module; a [module template](https://github.com/ttimasdf/nixos-config-module) is available for reference (see [Using this config](#using-this-config)).
- **Modular Design**: Unifies [NixOS](https://nixos.org/), [nix-darwin](https://github.com/LnL7/nix-darwin), and [home-manager](https://github.com/nix-community/home-manager) configuration in a single flake using [nixos-unified](https://github.com/srid/nixos-unified).
- **Auto-wiring**: Automatically discovers and imports configurations into the final flake output from the directory structure, see the chapter [Structure](#structure) below.
- **Image Building**: Build ISO/VM/Cloud images from any machine config using `nixos-rebuild build-image` (e.g., `nixos-rebuild build-image --flake .#savior --image-variant iso-xfce`).

## Using this config

You can clone or fork this repository as a configuration template. Reusable packages, portable overlays, and package-specific modules are published separately in [`ttimasdf/nix-packages`](https://github.com/ttimasdf/nix-packages).

To include this module in your NixOS config, you need to provide a `private-module` input. This allows for separation of public and private configuration details.

For public users who want to use this config as a base or reference without access to the private repository, please use the [public module template](https://github.com/ttimasdf/nixos-config-module) in place of the private module.

Add the following to your `flake.nix` inputs:

```nix
inputs = {
  ttimasdf-nixos-config = {
    url = "github:ttimasdf/nixos-config";
    # Follow the private-module input to the public module template
    inputs.private-module.follows = "private-module";
  };

  # The public module template for the private module
  private-module = {
    url = "github:ttimasdf/nixos-config-module";
  };
};
```

For packages and overlays, consume the dedicated flake directly:

```nix
inputs.known-rabbit-packages = {
  url = "github:ttimasdf/nix-packages";
  inputs.nixpkgs.follows = "nixpkgs";
};

# In a NixOS module:
nixpkgs.overlays = [
  inputs.known-rabbit-packages.overlays.default
  # Opt-in existing-package overrides:
  inputs.known-rabbit-packages.overlays.kscreen
];
```

## Structure

The repository is organized into the following main directories:

-   `flake.nix`: The main Nix flake file, defining inputs and outputs for the entire configuration.
-   `packages/`: Local packages that cannot be published, currently private-source packages.
-   `known-rabbit-packages` input: Public packages, portable overlays, and package-specific NixOS modules.
-   `configurations/`: Contains machine-specific NixOS and Home Manager configurations.
    -   `configurations/home/<user>.nix`: Defines Home Manager configurations for a specific user. The presence of such a file automatically registers `<user>` for both Home Manager and system-level user configurations. A directory like `configurations/home/<user>/default.nix` is also supported.
    -   `configurations/nixos/<hostname>/`: NixOS configurations for different machines.
    -   `configurations/users/<user>.nix`: Provides system-level user configurations (for user groups, system permissions) for users defined in `configurations/home/`. A directory like `configurations/users/<user>/default.nix` is also supported.
-   `modules/`: Reusable Nix modules for various system and user settings.
    -   `modules/home/`: Home Manager modules.
    -   `modules/nixos/`: NixOS modules, including common settings, GUI environments, and specific features like `label-suffix`.
    -   `modules/flake/`: Flake modules for Nix config debugging and package development.
-   `README.md`: Contains `xc` task definitions for common development and NixOS management tasks (see Tasks section).
-   `nixos-version-hint.txt`: A file to specify a custom suffix for the NixOS system label.

### Flake Outputs

Each of the directories are wired to the corresponding flake output, as indicated in the below table:


| Directory                                     | Flake Output                                                    |
| --------------------------------------------- | --------------------------------------------------------------- |
| `configurations/nixos/foo.nix`<sup>(1)</sup>  | `nixosConfigurations.foo`                                       |
| `configurations/darwin/foo.nix`<sup>(1)</sup> | `darwinConfigurations.foo`                                      |
| `configurations/home/foo.nix`<sup>(1)</sup>   | `legacyPackages.${system}.homeConfigurations.foo`<sup>(2)</sup> |
| `modules/nixos/foo.nix`                       | `nixosModules.foo`                                              |
| `modules/darwin/foo.nix`                      | `darwinModules.foo`                                             |
| `modules/flake/foo.nix`                       | `flakeModules.foo`                                              |

(1): This path could as well be `configurations/nixos/foo/default.nix`. Likewise for other output types.

(2): Why `legacyPackages`? Because, creating a home-manager configuration [requires `pkgs`](https://github.com/srid/nixos-unified/blob/47a26bc9118d17500bbe0c4adb5ebc26f776cc36/nix/modules/flake-parts/lib.nix#L97). See <https://github.com/nix-community/home-manager/issues/3075>

Public package outputs are provided by the separate `nix-packages` flake. Local package files are only injected into host `pkgs` through the local overlay.

### Home Manager configurations: `configurations/home/`

The [`modules/nixos/common/myusers.nix`](modules/nixos/common/myusers.nix) module automatically discovers users by listing all `.nix` files (e.g., `configurations/home/<user>.nix` or `configurations/home/<user>/default.nix`) in `configurations/home/`. These discovered users are used as the default for the `rabit.nixos.myusers` option. This option can also be manually specified to define the list of users. For each user in `rabit.nixos.myusers`, their respective Home Manager configuration is loaded into `config.home-manager.users.<user>`.


In all cases, home manager configuration is loaded by [nixos-unified autowire](https://github.com/srid/nixos-unified/blob/1f8ab18330354d2305a0d793da58a6ef83e2857c/nix/modules/flake-parts/autowire.nix#L60-L63) and exposed into flake `flake.perSystem.legacyPackages.homeConfigurations`,

### NixOS configurations: `configurations/nixos/`

`configurations/nixos` is loaded by [nixos-unified autowire](https://github.com/srid/nixos-unified/blob/1f8ab18330354d2305a0d793da58a6ef83e2857c/nix/modules/flake-parts/autowire.nix#L38-L41) into `flake.nixosConfigurations` via `forAllNixFiles`.

#### common module: `configurations/nixos/common/`

`configurations/nixos/common` includes some common modules shared by nixos and nix-darwin. Do not add NixOS-specific config into this module.


### System-level user configurations: `configurations/users/`

For each user in `rabit.nixos.myusers` (which defaults to users automatically discovered from `configurations/home/`, but can also be manually specified), their corresponding system-level user configuration (`configurations/users/<user>.nix` or `configurations/users/<user>/default.nix`) is loaded by [`modules/nixos/common/myusers.nix`](modules/nixos/common/myusers.nix) into `config.users.users.<user>`.

See [NixOS Options Search: `users.user`](https://search.nixos.org/options?channel=unstable&query=users.user) for available options.


### Version Hint Feature

The version hint feature allows you to append a custom string to your NixOS system label, which is useful for distinguishing between different builds or versions.

**How to Use:**

1.  **Create the Version Hint File**: In the root of this repository, create a file named `nixos-version-hint.txt`.
2.  **Add Your Version Hint**: Open `nixos-vers`ion-hint.txt` and add your desired version hint. For example:
    ```
    my-custom-build
    ```
    *   **Important**: The build will fail if this file is empty or contains the string `changeme`.
3.  **Rebuild Your System**: When you rebuild your NixOS system, the content of `nixos-version-hint.txt` will be appended to your system's label.

**Pre-commit Hook Integration:**

A pre-commit hook automatically validates version hint updates:
- When committing `.nix` files, the hook ensures `nixos-version-hint.txt` is also staged for commit
- The hook displays current work tree value and last committed value for reference

**Skip and Reset Functionality:**

- **Skip Version Hint Check**: Create a `.nixos-version-hint-skip` file to bypass version hint validation for the current commit
  > **Warning**: The skip file remains valid for the current worktree until manually deleted. Remember to delete it after use to re-enable version hint validation.
- **Reset Version Hint**: Use `xc version-hint reset` to restore the version hint to the last committed value
- **Skip via Command**: Use `xc version-hint skip` to create the skip file automatically

This feature is implemented via the [`modules/nixos/common/version-hint.nix`](modules/nixos/common/version-hint.nix) module and validated by [`scripts/pre-commit-nixos-version-hint.sh`](scripts/pre-commit-nixos-version-hint.sh).


## Tasks

The tasks in this section are compatible with the [xc task runner](https://xcfile.dev/). You can execute any of these commands simply by running `xc <task-name>`, e.g., `xc build`.

### update

Update nix flake

```bash
nix flake update
```

### build

Build and activate the new configuration, and make it the boot default

```bash
nh os switch $@
```

### build-xfce-iso

Build xfce-iso for NixOS configuration [`savior`](configurations/nixos/savior).
I usually use this ISO as a system rescue CD.

```bash
nixos-rebuild build-image --flake .#savior --image-variant iso-xfce
```

### build-nas-vm

```bash
nixos-rebuild build-image --flake .#basenji --image-variant proxmox
```

### list

List system generations

```bash
nixos-rebuild list-generations
```

### list-user

List user profile generations

Inputs: PROFILE

```bash
nix-env --list-generations $@
```

### clean

Cleanup nix store

```bash
nh clean all
```

### test

Build and activate the new configuration, and make it the boot default

```bash
nh os build $@
```

### version-hint

Update version hint file, set `skip` to skip check, set `reset` to restore last value

Inputs: CONTENT

```bash
#!/usr/bin/env bash
set -euxo pipefail

version_hint_file="nixos-version-hint.txt"
version_hint_skip_file=".nixos-version-hint-skip"

if [ "$CONTENT" == "skip" ]; then
  git restore --staged "$version_hint_file"
  git restore "$version_hint_file"
  touch "$version_hint_skip_file"
elif [ "$CONTENT" == "reset" ]; then
  git restore --staged "$version_hint_file"
  git restore "$version_hint_file"
  rm -f "$version_hint_skip_file"
else
  rm -f "$version_hint_skip_file"
  printf '%s' "$CONTENT" > "$version_hint_file"
  git add "$version_hint_file"
fi
```


### remove-generation

Interactively remove generations

```bash
nixos-rebuild list-generations
while read -p 'remove generation:' n; do
  sudo nix-env -p /nix/var/nix/profiles/system --delete-generations "$n"
  nixos-rebuild list-generations
done
```

### trim-generations

> [!WARNING]
> This command is obsolete, please use `clean` command instead.

Trim old NixOS generations for a given profile with optional arguments.

Inputs: GENERATIONS, DAYS, PROFILE

- **GENERATIONS** — Number of generations to keep (default: `3`)
- **DAYS** — Number of days of system history to trim to (default: `3`)
- **PROFILE** — Name of the Nix profile (default: `system`)

```bash
# trim-generations: Trim old NixOS generations (obsolete; use 'clean' instead).
# Usage: trim-generations [GENERATIONS] [DAYS] [PROFILE]
# Defaults: GENERATIONS=3, DAYS=3, PROFILE=system

if [ "$PROFILE" = "system" ]; then
  sudo=sudo
else
  sudo=
fi

$sudo bash scripts/nixos-trim-generations.sh "$GENERATIONS" "$DAYS" "$PROFILE"
```


### lint

Lint nix files

```bash
nix fmt
```

### check

Check nix flake

```bash
git add .
nix flake check $@
```

### dev

Manually enter dev shell

```bash
nix develop
```

### pre-commit-hook

Install pre-commit hook

```bash
sh ./scripts/install-pre-commit-hook.sh
```

## Developing Packages and Overlays

Public packages and portable overlays are maintained in [`ttimasdf/nix-packages`](https://github.com/ttimasdf/nix-packages). That repository provides direct flake package outputs, a NUR-compatible `default.nix`, portable overlays, and package-specific NixOS modules.

Hosts import published modules explicitly through `known-rabbit-packages.nixosModules.<name>`. `known-rabbit-packages.nixosModules.all` is available when a host intentionally wants the complete published module set. The reference configuration trusts and applies every distinct overlay exported by `known-rabbit-packages`; the local [`modules/nixos/programs/default.nix`](modules/nixos/programs/default.nix) scaffold only collects custom program modules defined beside it.

The local `packages/` directory is reserved for packages that cannot be published, such as private-source software. Direct package files and directories containing `default.nix` are added to host package sets by [`modules/nixos/common/nixpkgs-overlays.nix`](modules/nixos/common/nixpkgs-overlays.nix).
