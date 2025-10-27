# Commonly used project files

- `flake.nix`: The main Nix flake file, defining inputs and outputs for the entire configuration.
- `modules/flake/toplevel.nix`: Defines the top-level structure or entry points for the flake, imported by nixos-unified autowire.
- `modules/nixos/`: Contains reusable NixOS modules for various system settings, GUI environments, and specific features.
- `pkgs/`: Directory for custom packages and overlays.
- `overlays/`: Directory within `pkgs/` where `.nix` files are automatically discovered and applied as Nixpkgs overlays.
- `configurations/`: Contains machine-specific NixOS and Home Manager configurations.
- `justfile`: Defines convenient `just` commands for common development tasks like updating the flake, linting, checking, and entering a development shell.

# Writing Nix Config

## Write an overlay
All `.nix` files placed in the `overlays/` directory are automatically discovered and applied as Nixpkgs overlays. This is handled by the `modules/nixos/common/overlays.nix` module.

Overlays can be defined in two ways:
1.  **Function with Flake Inputs**: If an overlay file is a function, it will receive `flake`, `lib`, and `config` as arguments.
    ```nix
    # overlays/my-complex-overlay.nix
    { flake, lib, config, ... }:

    final: prev: {
      # ... your overlay logic using flake, lib, config ...
    }
    ```
2.  **Raw Overlay Function**: Simple overlays that only depend on `final` and `prev` (the standard Nixpkgs arguments) are also supported.
    ```nix
    # overlays/my-simple-overlay.nix
    final: prev: {
      # ... your overlay logic using final and prev ...
    }
    ```
Example: `overlays/example.nix` demonstrates modifying `haskell.compiler` attributes.

## Write a new package
All `.nix` files and directories placed in the `packages/` directory are automatically discovered and transformed into a nested attribute set of derivations using `lib.packagesFromDirectoryRecursive`.

To add a new package:
1.  **Create a New Directory**: Inside `packages/`, create a new directory for your package (e.g., `packages/my-new-package/`).
2.  **Create `package.nix` or other `.nix` files**:
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
      # use fetchurl/fetchFromGitHub/requireFile etc,
      # add necessary instructions for user
      # to add hash or required files.

      # ... your package logic here ...
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
    `my-app.nix` would be accessible as `pkgs.my-namespace.my-app`, and `my-tool/package.nix` as `pkgs.my-namespace.my-tool`.

3.  **Using your new package**:
    - If your package directory contains a single `package.nix` file, it will typically be accessible directly as `pkgs.your-package-name`.
    - If your package directory returns more than one package, you will need to use the directory name as a namespace (e.g., `pkgs.my-namespace.my-app`).

    ```nix
    # In configurations/nixos/viscacha/configuration.nix
    environment.systemPackages = with pkgs; [
      my-new-package # For a single package defined in packages/my-new-package/package.nix
      my-namespace.my-app # For a package within a namespace
    ];
    ```

# Troubleshooting Nix config

## Run a nix check
Use `just check` to check the flake for errors.

## Run a nix build
Use `just rebuild` to rebuild the NixOS configuration.
