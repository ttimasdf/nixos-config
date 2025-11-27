# KnownRabbit NixOS Config

This repository contains my personal NixOS configuration, based on the `juspay/nixos-unified-template`. It aims to provide a unified and reproducible system configuration for various machines.

## Features

*   **NixOS Unified Template**: Leverages `nixos-unified` for a streamlined and modular configuration approach.
*   **Home Manager**: Manages user-specific configurations and packages for a consistent environment across different systems.
*   **Nix-Darwin**: Provides configuration for macOS systems, integrating them into the Nix ecosystem (though not explicitly used in this NixOS config, it's available as an input).
*   **Secure Boot with Lanzaboote**: Includes `lanzaboote` for managing secure boot, enhancing system security.
*   **Windows Applications Integration**: Utilizes `winapps` for seamless integration of Windows applications on NixOS.
*   **NixVim**: Integrates `nixvim` for a declarative Neovim configuration.
*   **Custom Label Suffix**: Allows adding a custom suffix to the NixOS system label for easy identification of different builds.

## Structure

The repository is organized into the following main directories:

*   `flake.nix`: The main Nix flake file, defining inputs and outputs for the entire configuration.
*   `configurations/`: Contains machine-specific NixOS and Home Manager configurations.
    *   `configurations/home/<user>.nix`: Defines Home Manager configurations for a specific user. The presence of such a file automatically registers `<user>` for both Home Manager and system-level user configurations. A directory like `configurations/home/<user>/default.nix` is also supported.
    *   `configurations/nixos/<hostname>/`: NixOS configurations for different machines.
    *   `configurations/users/<user>.nix`: Provides system-level user configurations (for user groups, system permissions) for users defined in `configurations/home/`. A directory like `configurations/users/<user>/default.nix` is also supported.
*   `modules/`: Reusable Nix modules for various system and user settings.
    *   `modules/home/`: Home Manager modules.
    *   `modules/nixos/`: NixOS modules, including common settings, GUI environments, and specific features like `label-suffix`.
    *   `modules/flake/`: Flake modules for Nix config debugging and package development.
*   `justfile`: Defines convenient `just` commands for common development tasks like updating the flake, linting, checking, and entering a development shell.
*   `nixos-version-hint.txt`: (Optional) A file to specify a custom suffix for the NixOS system label.


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


## Development Workflow

This repository uses `just` for task automation. Ensure you have `just` installed (`nix-shell -p just` or `cargo install just`).

### NixOS Commands

*   **Update Flake Inputs**:
    ```bash
    just update
    ```
*   **Build and Activate NixOS Configuration**:
    ```bash
    just build
    ```
*   **List Generations**:
    ```bash
    just list-generations
    ```
*   **Remove Generation**:
    ```bash
    just remove-generation
    ```
*   **Clean Nix Store**:
    ```bash
    just clean
    ```

### Development Commands

*   **Install Git pre-commit hooks**:
    ```bash
    just pre-commit-hook
    ```
*   **Format Nix Files**:
    ```bash
    just lint
    ```
*   **Check Flake for Errors**:
    ```bash
    just check
    ```
*   **Manage Version Hint File Before Git Commit**:
    ```bash
    # Set custom version hint
    just version-hint "my-custom-build"

    # Skip version hint check
    just version-hint skip

    # Reset version hint to last committed value
    just version-hint reset
    ```

### Obsolete commands

*   **Rebuild NixOS Configuration (Obsolete)**:
    ```bash
    just rebuild-with-nixos-rebuild
    ```
    > **Note**: This command is obsolete, please use `just build` instead.

*   **Trim Generations (Obsolete)**:
    ```bash
    just trim-generations
    ```
    > **Note**: This command is obsolete, please use `just clean` instead.

*   **Activate Configuration (Obsolete)**:
    ```bash
    just run
    ```
    > **Note**: This command is obsolete and will prompt for confirmation. Use `just build` instead.

*   **Enter Development Shell**:
    ```bash
    just dev
    ```
    > **Note**: dev shell is automatically activated by direnv, so this command is not
    useful in any way.

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
- **Reset Version Hint**: Use `just version-hint reset` to restore the version hint to the last committed value
- **Skip via Command**: Use `just version-hint skip` to create the skip file automatically

This feature is implemented via the `modules/nixos/common/version-hint.nix` module and validated by `scripts/pre-commit-nixos-version-hint.sh`.

## Writing Package Overlay

This repository provides a streamlined way to manage Nixpkgs overlays. All `.nix` files in the `overlays/` directory are automatically discovered and applied, making it easy to extend and customize your package set. For detailed examples and templates, please refer to the [`overlays/overlay-template.md`](./overlays/overlay-template.md) file.

Key features of the overlay system in this configuration include:

1.  **Automatic Discovery**: Any `.nix` file placed in `overlays/` is automatically loaded as a Nixpkgs overlay. This is managed by the `modules/nixos/common/nixpkg-overlays.nix` module.
2.  **Flexible Overlay Definitions**: You can define overlays in two primary ways:
    *   **Standard Overlay**: A simple function that takes `final` and `prev` as arguments.
    *   **Function with Flake Inputs**: For more complex scenarios, your overlay can be a function that receives `flake`, `lib`, and `config`, allowing it to adapt based on the system's configuration and flake inputs.

This setup simplifies the management of custom packages and modifications, promoting a clean and organized repository structure.

## Writing a New Package

This repository allows for easy integration of custom Nix packages. All `.nix` files and directories placed in the `packages/` directory are automatically discovered and transformed into a nested attribute set of derivations using `lib.packagesFromDirectoryRecursive`. This means you don't typically need to manually add new packages from `packages/` to your `flake.nix`.

### Example Directory Structure

Consider the following structure within `packages/`:

```
packages/
├── a.nix
├── b.nix
├── c
│  ├── my-extra-feature.patch
│  ├── package.nix
│  └── support-definitions.nix
└── my-namespace
   ├── d.nix
   ├── e.nix
   └── f
      └── package.nix
```

### Accessing Packages from the Example Structure

Based on the `packagesFromDirectoryRecursive` mechanism, these packages would be accessible as follows:

*   `pkgs.a` (from `packages/a.nix`)
*   `pkgs.b` (from `packages/b.nix`)
*   `pkgs.c` (from `packages/c/package.nix`)
*   `pkgs.my-namespace.d` (from `packages/my-namespace/d.nix`)
*   `pkgs.my-namespace.e` (from `packages/my-namespace/e.nix`)
*   `pkgs.my-namespace.f` (from `packages/my-namespace/f/package.nix`)

To add a new package:

1.  **Create a New Directory**: Inside `packages/`, create a new directory for your package. For example, `packages/my-new-package/`.
2.  **Create `package.nix` or other `.nix` files**: Inside your new package directory, create a `package.nix` file (for a single package definition) or multiple `.nix` files (for multiple packages within a namespace).

    **Example: Single package in `package.nix`**
    ```nix
    # packages/my-new-package/package.nix
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
    If your directory contains multiple `.nix` files or subdirectories with `package.nix`, they will be exposed under a namespace corresponding to the directory name.

    ```
    packages/my-namespace/
    ├── my-app.nix
    └── my-tool/
        └── package.nix
    ```
    In this case, `my-app.nix` would be accessible as `pkgs.my-namespace.my-app`, and `my-tool/package.nix` as `pkgs.my-namespace.my-tool`.

3.  **Using your new package**:
    You can then use your new package in your NixOS configuration or Home Manager.

    - If your package directory (`packages/your-package-name/`) contains a single `package.nix` file, it will typically be accessible directly as `pkgs.your-package-name`.
    - If your package directory returns more than one package (e.g., it contains multiple `.nix` files or subdirectories defining packages), you will need to use the directory name as a namespace. For example, if `packages/my-namespace/` contains `my-app.nix`, you would refer to it as `pkgs.my-namespace.my-app`.

    ```nix
    # In configurations/nixos/viscacha/configuration.nix
    environment.systemPackages = with pkgs; [
      my-new-package # For a single package defined in packages/my-new-package/package.nix
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
