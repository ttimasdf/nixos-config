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
*   `nixos-label-suffix.txt`: (Optional) A file to specify a custom suffix for the NixOS system label.

## Development Workflow

This repository uses `just` for task automation. Ensure you have `just` installed (`nix-shell -p just` or `cargo install just`).

*   **Update Flake Inputs**:
    ```bash
    just update
    ```
*   **Format Nix Files**:
    ```bash
    just lint
    ```
*   **Check Flake for Errors**:
    ```bash
    just check
    ```
*   **Enter Development Shell**:
    ```bash
    just dev
    ```
*   **Activate Configuration**:
    ```bash
    just run
    ```

### Label Suffix Feature

The `label-suffix` feature allows you to append a custom string to your NixOS system label, which is useful for distinguishing between different builds or versions.

**How to Use:**

1.  **Create the Suffix File**: In the root of this repository, create a file named `nixos-label-suffix.txt`.
2.  **Add Your Suffix**: Open `nixos-label-suffix.txt` and add your desired suffix. For example:
    ```
    my-custom-build
    ```
    *   **Important**: The build will fail if this file is empty or contains the string `changeme`.
3.  **Rebuild Your System**: When you rebuild your NixOS system, the content of `nixos-label-suffix.txt` will be appended to your system's label.

This feature is implemented via the `modules/nixos/common/label-suffix.nix` module.
