# Binary Ninja Nix Package

This package provides derivations for Binary Ninja, an interactive decompiler,
disassembler, debugger, and binary analysis platform.

It dynamically generates packages for different editions (e.g., commercial, personal)
and versions (stable, dev) based on the data in `./releases.json`.

## Usage

To use this package, you can select a specific edition and version.
For example:
  - `pkgs.binaryninja.binaryninja-commercial` for the latest stable commercial version.
  - `pkgs.binaryninja.binaryninja-personal-dev` for the latest development personal version.

You can also access all available versions for a given edition via the `allVersions`
passthru attribute. For example:
  - `pkgs.binaryninja.binaryninja-commercial-dev.allVersions."5.2.8089-dev"`
  - `pkgs.binaryninja.binaryninja-commercial.allVersions."5.1.8005"`

## `releases.json` Structure

The `releases.json` file should contain a JSON object where keys are editions
(e.g., "commercial", "personal") and values are objects mapping version strings
to their corresponding SHA256 hashes.

Example `releases.json` entry:
```json
{
  "commercial": {
    "3.5.4377-dev": "sha256-...",
    "3.4.4200": "sha256-..."
  },
  "personal": {
    "3.5.4377-dev": "sha256-...",
    "3.4.4200": "sha256-..."
  }
}
