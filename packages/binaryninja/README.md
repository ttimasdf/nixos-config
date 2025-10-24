# Binary Ninja Nix Package

This package provides derivations for Binary Ninja, an interactive decompiler,
disassembler, debugger, and binary analysis platform.

It dynamically generates packages for different editions (e.g., commercial, personal)
and versions (stable, dev) based on the data in `./releases.json`.

## Usage

To use Binary Ninja in your NixOS configuration:

1. **Add Binary Ninja files** to the Nix store and populate `releases.json` (see [Adding Binary Ninja Files](#adding-binary-ninja-files) section below)
2. **Add the package** to your `configuration.nix`:
   ```nix
   environment.systemPackages = with pkgs; [
     binaryninja.binaryninja-commercial  # or binaryninja-personal, etc.
   ];
   ```

Once configured, you can select a specific edition and version:
  - `pkgs.binaryninja.binaryninja-commercial` for the latest stable commercial version.
  - `pkgs.binaryninja.binaryninja-personal-dev` for the latest development personal version.

You can also access all available versions for a given edition via the `allVersions`
passthru attribute. For example:
  - `pkgs.binaryninja.binaryninja-commercial-dev.allVersions."5.2.8089-dev"`
  - `pkgs.binaryninja.binaryninja-commercial.allVersions."5.1.8005"`

## Adding Binary Ninja Files

To use this package, you need to add Binary Ninja files to the Nix store and populate the `releases.json` file with their SHA256 hashes.

### Manual Method
1. Download Binary Ninja files (e.g., `binaryninja_linux_stable_commercial.5.1.8005.zip`)
2. Add each file to the Nix store and get its hash:
   ```bash
   nix-prefetch-url file:///path/to/binaryninja_linux_stable_commercial.5.1.8005.zip
   ```
3. Add the hash to `releases.json` under the appropriate edition and version

### Automated Method
Use the provided `nix-add.sh` script to automatically process Binary Ninja files:
```bash
# Process all binaryninja_linux*.zip files in current and subdirectories
./nix-add.sh

# Process specific files
./nix-add.sh binaryninja_linux_stable_commercial.5.1.8005.zip binaryninja_linux_dev_personal.5.2.8089-dev.zip
```

The script will:
- Find Binary Ninja files (if none specified)
- Add them to the Nix store
- Generate SHA256 hashes
- Output the hashes for you to add to `releases.json`

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
