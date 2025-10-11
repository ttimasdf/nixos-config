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
    *   `configurations/home/`: Home Manager configurations for users.
    *   `configurations/nixos/`: NixOS configurations for different machines (e.g., `viscacha`).
*   `modules/`: Reusable Nix modules for various system and user settings.
    *   `modules/home/`: Home Manager modules.
    *   `modules/nixos/`: NixOS modules, including common settings, GUI environments, and specific features like `label-suffix`.
*   `justfile`: Defines convenient `just` commands for common development tasks like updating the flake, linting, checking, and entering a development shell.
*   `nixos-version-hint.txt`: (Optional) A file to specify a custom suffix for the NixOS system label.

## Development Workflow

This repository uses `just` for task automation. Ensure you have `just` installed (`nix-shell -p just` or `cargo install just`).

### NixOS Commands

*   **Update Flake Inputs**:
    ```bash
    just update
    ```
*   **Rebuild NixOS Configuration**:
    ```bash
    just rebuild
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

*   **Activate Configuration (Obsolete)**:
    ```bash
    just run
    ```
    > **Note**: This command is obsolete and will prompt for confirmation. Use `just rebuild` instead.

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
