# KnownRabbit NixOS Config

The most versatile NixOS config.

## Hosts

- **viscacha**: Personal config for @ttimasdf
- **MNIX**: Personal config for @Tardis07
- **savior**: Minimal config for building ISOs (system rescue & benchmarking)

## Features

- **Modular Design**: Unifies [NixOS](https://nixos.org/), [nix-darwin](https://github.com/LnL7/nix-darwin), and [home-manager](https://github.com/nix-community/home-manager) configuration in a single flake using [nixos-unified](https://github.com/srid/nixos-unified).
- **Auto-wiring**: Automatically discovers and imports configurations into the final flake output from the directory structure, see the chapter [Structure](#structure) below.
- **NixOS Generators**: Build ISO/VM/Cloud images from any machine config (e.g., `nix build .#nixosConfigurations.savior.config.formats.gnome-iso`) using [nixos-generators](https://github.com/nix-community/nixos-generators).
- **Version Hints**: Custom suffixes for system version numbers in boot menus and ISO filenames.


## Tasks
[![xc compatible](https://xcfile.dev/badge.svg)](https://xcfile.dev)

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

## Structure

The repository is organized into the following main directories:

-   `flake.nix`: The main Nix flake file, defining inputs and outputs for the entire configuration.
-   `packages/`: Custom packages (automatically discovered).
-   `overlays/`: Nixpkgs overlays (automatically discovered).
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


### Home Manager configurations: `configurations/home/`

The `modules/nixos/common/myusers.nix` module automatically discovers users by listing all `.nix` files (e.g., `configurations/home/<user>.nix` or `configurations/home/<user>/default.nix`) in `configurations/home/`. These discovered users are used as the default for the `rabit.nixos.myusers` option. This option can also be manually specified to define the list of users. For each user in `rabit.nixos.myusers`, their respective Home Manager configuration is loaded into `config.home-manager.users.<user>`.


In all cases, home manager configuration is loaded by [nixos-unified autowire](https://github.com/srid/nixos-unified/blob/1f8ab18330354d2305a0d793da58a6ef83e2857c/nix/modules/flake-parts/autowire.nix#L60-L63) and exposed into flake `flake.perSystem.legacyPackages.homeConfigurations`,

### NixOS configurations: `configurations/nixos/`

`configurations/nixos` is loaded by [nixos-unified autowire](https://github.com/srid/nixos-unified/blob/1f8ab18330354d2305a0d793da58a6ef83e2857c/nix/modules/flake-parts/autowire.nix#L38-L41) into `flake.nixosConfigurations` via `forAllNixFiles`.

#### common module: `configurations/nixos/common/`

`configurations/nixos/common` includes some common modules shared by nixos and nix-darwin. Do not add NixOS-specific config into this module.


### System-level user configurations: `configurations/users/`

For each user in `rabit.nixos.myusers` (which defaults to users automatically discovered from `configurations/home/`, but can also be manually specified), their corresponding system-level user configuration (`configurations/users/<user>.nix` or `configurations/users/<user>/default.nix`) is loaded by [modules/nixos/common/myusers.nix](modules/nixos/common/myusers.nix) into `config.users.users.<user>`.

See [NixOS Options Search: `users.user`](https://search.nixos.org/options?channel=unstable&query=users.user) for available options.


### Version Hint Feature

The version hint feature allows you to append a custom string to your NixOS system label, which is useful for distinguishing between different builds or versions.

**How to Use:**

1.  **Create the Version Hint File**: In the root of this repository, create a file named `nixos-version-hint.txt`.
2.  **Add Your Version Hint**: Open `nixos-version-hint.txt` and add your desired version hint. For example:
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

This feature is implemented via the `modules/nixos/common/version-hint.nix` module and validated by `scripts/pre-commit-nixos-version-hint.sh`.

## Writing a Package Overlay

You can override or extend Nixpkgs packages by creating overlays in the `overlays/` directory.

> [!IMPORTANT]
> Overlays in this repository use the following signature at the top, notably the `{ flake, ... }` part, which is *different from the official Nixpkgs method* (see [overlays/overlay-template.md](overlays/overlay-template.md)):

```nix
{ flake, ... }:
final: prev: {
  # ...your overrides here
}
```

The overlays are autowired by [nixos-unified autowire.nix](https://github.com/srid/nixos-unified/blob/90171c6936a8332ede17e09e337a0e71f4e659b1/nix/modules/flake-parts/autowire.nix#L54-L56) with arguments defined in [lib.nix](https://github.com/srid/nixos-unified/blob/90171c6936a8332ede17e09e337a0e71f4e659b1/nix/modules/flake-parts/lib.nix#L3-L6).

For example, to override the `hello` package:

```nix
# overlays/hello-override.nix
{ flake, ... }:
final: prev: {
  hello = prev.hello.overrideAttrs (oldAttrs: {
    version = "2.12.1";
    src = prev.fetchurl {
      url = "https://ftp.gnu.org/gnu/hello/hello-2.12.1.tar.gz";
      sha256 = "sha256-differenthashgoeshere";
    };
  });
}
```

See [overlays/overlay-template.md](overlays/overlay-template.md) for more overlay examples and best practices.


## Writing a New Package

This repository allows for easy integration of custom Nix packages. All `.nix` files and directories placed in the `packages/` directory are automatically discovered and transformed into a nested attribute set of derivations (handled by [`modules/nixos/common/nixpkg-overlays.nix`](modules/nixos/common/nixpkg-overlays.nix)). This means you don't typically need to manually add new packages from `packages/` to your `flake.nix`.

### Example Directory Structure

Consider the following structure within `packages/`:

```
packages/
├── a.nix
├── b.nix
├── c
│  ├── my-extra-feature.patch
│  ├── default.nix
│  └── support-definitions.nix
└── my-namespace
   ├── d.nix
   ├── e.nix
   └── f
      └── default.nix
```

### Accessing Packages from the Example Structure

Based on the `packagesFromDirectoryRecursive` mechanism, these packages would be accessible as follows:

*   `pkgs.a` (from `packages/a.nix`)
*   `pkgs.b` (from `packages/b.nix`)
*   `pkgs.c` (from `packages/c/default.nix`)
*   `pkgs.my-namespace.d` (from `packages/my-namespace/d.nix`)
*   `pkgs.my-namespace.e` (from `packages/my-namespace/e.nix`)
*   `pkgs.my-namespace.f` (from `packages/my-namespace/f/default.nix`)

To add a new package:

1.  **Create a New Directory**: Inside `packages/`, create a new directory for your package. For example, `packages/my-new-package/`.
2.  **Create `default.nix` or other `.nix` files**: Inside your new package directory, create a `default.nix` file (for a single package definition) or multiple `.nix` files (for multiple packages within a namespace).

    **Example: Single package in `default.nix`**
    ```nix
    # packages/my-new-package/default.nix
    { lib, stdenv, fetchurl }:

    stdenv.mkDerivation {
      pname = "my-new-package";
      version = "1.0.0";

      src = fetchurl {
        url = "https://example.com/my-new-package-1.0.0.tar.gz";
        hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Replace with actual hash
      };

      # Add build and install phases as needed
      installPhase = ''
        mkdir -p $out/bin
        echo "Hello from my new package!" > $out/bin/my-new-package
        chmod +x $out/bin/my-new-package
      '';

      meta = {
        description = "A simple example package";
        homepage = "https://example.com/my-new-package";
        license = lib.licenses.mit;
        platforms = lib.platforms.linux;
      };
    }
    ```

    **Example: Multiple packages within a directory (creating a namespace)**
    If your directory contains multiple `.nix` files or subdirectories with `default.nix`, they will be exposed under a namespace corresponding to the directory name.

    ```
    packages/my-namespace/
    ├── my-app.nix
    └── my-tool/
        └── default.nix
    ```
    In this case, `my-app.nix` would be accessible as `pkgs.my-namespace.my-app`, and `my-tool/default.nix` as `pkgs.my-namespace.my-tool`.

3.  **Using your new package**:
    You can then use your new package in your NixOS configuration or Home Manager.

    - If your package directory (`packages/your-package-name/`) contains a single `default.nix` file, it will typically be accessible directly as `pkgs.your-package-name`.
    - If your package directory returns more than one package (e.g., it contains multiple `.nix` files or subdirectories defining packages), you will need to use the directory name as a namespace. For example, if `packages/my-namespace/` contains `my-app.nix`, you would refer to it as `pkgs.my-namespace.my-app`.

    ```nix
    # In configurations/nixos/viscacha/configuration.nix
    environment.systemPackages = with pkgs; [
      my-new-package # For a single package defined in packages/my-new-package/default.nix
      my-namespace.my-app # For a package within a namespace
    ];
    ```

## Debugging Packages and Overlays

When developing or debugging custom packages and overlays, it's often useful to have a dedicated shell environment. Here are instructions to set up a build shell and a run shell.

### Build Shell

To enter a development shell for a specific package (e.g., `binaryninja-commercial-dev`) and prepare output directories for building, first navigate to the package's directory:

```bash
cd packages/binaryninja # Or your specific package directory
# dev shell for packages
nix develop .#binaryninja-commercial-dev
# dev shell for overlays
nix develop .#nixosConfigurations.viscacha.pkgs._010editor

# in dev shell
mkdir -p result/{output,unpack} && pushd result/unpack && export out=$(realpath ../output)
```

Run package phases manually inside dev shell.

```bash
runPhase unpackPhase && export out=$(realpath ../output)
# runPhase patchPhase
# runPhase configurePhase
# runPhase buildPhase
# runPhase checkPhase
runPhase installPhase
runPhase fixupPhase
runPhase installCheckPhase
runPhase distPhase
```

### Run Shell

To enter a `nix-shell` environment and prepare output directories for running/testing, first navigate to the package's directory with a `shell.nix`:

```bash
cd packages/binaryninja # Or your specific package directory
nix-shell .
mkdir -p result/{output,unpack} && pushd result/output
```

These commands provide a way to isolate your development and testing environments, making it easier to debug issues with your Nix packages and overlays.
