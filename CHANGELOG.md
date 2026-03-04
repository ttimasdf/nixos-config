# Changelog

All notable changes to this NixOS configuration repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [v2026.03.04.01] - 2026-03-04

### Changed
- Updated nixpkgs input to the latest version
- Removed explicit ZFS 2.4 package pinning (no longer needed)
- Updated nixos-eval-config to check for direnv state before attempting to load

## [v2026.03.03.01] - 2026-03-03

### Added
- Added Easytier GUI package (v2.5.0) as a standalone application
- Added Easytier Manager package (v3.2.7) for managing Easytier connections
- Added cockpit-zfs module with de-branding patches to remove 45Drives references
- Added gh CLI to devshell dependencies for easier release management

### Changed
- Updated private flake input dependency
- Repackaged Astral desktop client from source using Flutter for better performance
- Added compatibility note for xc task runner in README

### Fixed
- Updated nixos-eval-config guard to prevent issues with direnv integration

## [v2026.02.27.01] - 2026-02-27

### Added
- Enabled kitty-in-tab feature for opening new terminal tabs in existing Kitty windows instead of launching new instances
- Added pnpm package manager to development tools
- Added ddccontrol service for controlling DDC/CI monitors
- Added user to i2c group for hardware monitor control

### Changed
- Updated documentation to clarify package discovery mechanism using `rabit-lib.forAllNixFiles` instead of nested namespaces
- Simplified README examples for package structure and usage
- Updated Wireshark package reference from `wireshark-qt` to `wireshark`
- Enabled systemd-networkd and nftables for basenji NAS configuration
- Improved dev shell workflow documentation with clearer phase execution examples

### Fixed
- Fixed typo in README (removed backtick in version-hint.txt path)

## [v2026.02.26.02] - 2026-02-26

### Added
- Implemented kitty-in-tab module with remote control functionality for tab management
- Added kitty-is-cmd-allowed security script to restrict remote commands
- Added nixos-eval-config shell function in devshell for querying NixOS configuration values
- Added .envrc watch for devshell.nix to auto-reload direnv on changes
- Imported private module's home-manager configuration for user 'u'

### Changed
- Moved nix-daemon proxy configuration from viscacha-specific to common nix-options module
- Updated proxy configuration to only apply when `rabit.nixos.http_proxy` is set
- Improved documentation for `rabit.nixos` options with clearer descriptions
- Removed hardcoded proxy settings from viscacha configuration

### Fixed
- Fixed default value for `rabit.nixos.http_proxy` to use `config.networking.proxy.default`

## [v2026.02.26.01] - 2026-02-26

### Added
- Added Astral package (Easytier desktop client) with capability wrapper for network administration
- Added programs.astral module with cap_net_admin capability support
- Added easytier package to productivity tools
- Added astral interface to trusted firewall interfaces

### Changed
- Updated burpsuite package to use integer gdkScale parameter instead of string
- Added GDK_DPI_SCALE environment variable for proper HiDPI scaling

### Fixed
- Fixed burpsuite gdkScale type from string to integer for proper scaling

## [v2026.02.23.01] - 2026-02-23

### Added
- Added new NAS host "basenji" with comprehensive ZFS, Cockpit, Samba, and Podman configuration
- Implemented ZFS pool management with auto-scrub and trim support
- Added Cockpit web management interface on port 9090
- Configured Samba file sharing with multiple shares (backups, docs, media, pictures)
- Added wsdd for Windows network discovery
- Enabled Podman container runtime with Docker compatibility
- Added Syncthing service for nas user
- Created nas user configuration with appropriate groups
- Added nixfmt to devshell for code formatting

### Changed
- Removed nixos-generators flake input in favor of built-in image building
- Renamed nixos-generators.nix module to images.nix
- Updated image building to use `nixos-rebuild build-image` command
- Added proxmox image variant support
- Removed ZFS version pinning warning from viscacha extra-fs specialisation
- Updated flake.lock with private-module following nixpkgs input

### Fixed
- Fixed easytier0 interface added to trusted firewall interfaces

## [v2026.02.13.01] - 2026-02-13

### Added
- Added yakit package to pentest tools
- Enabled appimage support with binfmt integration

### Changed
- Renamed home module from default.nix to all.nix for clarity
- Renamed _7zz-natspec package to _7zz-nls for consistency
- Renamed nixos-generators module to images module
- Updated all references from nixos-generators to images
- Enabled btrfs compression (zstd) for root, home, and nix subvolumes
- Updated yakit package to version 1.4.6-0206 with update script

### Fixed
- Removed hardcoded proxy environment variables from podman engine configuration
- Removed hardcoded Docker registry mirror from podman configuration

## [v2026.02.11.02] - 2026-02-11

### Changed
- Reverted _7zz-nls back to _7zz-natspec naming
- Reverted yakit package changes (back to version 1.4.5-1124)
- Reverted aliyun-cli overlay changes

## [v2026.02.11.01] - 2026-02-11

### Added
- Added yazi file manager with _7zz-nls support for user 'u'
- Added bun binary path to shell PATH when installed
- Enhanced px() proxy function to accept custom proxy URLs, ports, or host:port combinations
- Added fzf version compatibility check for distrobox environments

### Changed
- Renamed _7zz-natspec to _7zz-nls across all configurations
- Improved yazi shell integration to use pushd instead of cd for better directory navigation
- Updated yakit package to version 1.4.6-0206 with automatic update script
- Improved aliyun-cli overlay with version tracing

### Fixed
- Fixed yazi cwd-file handling to use file descriptor instead of temporary file

## [v2026.02.05.01] - 2026-02-05

### Added
- Added throne program with TUN mode support for viscacha
- Added kitty-terminfo, fzf, and zoxide to distrobox additional packages
- Added python3-venv and vim to distrobox packages

### Changed
- Removed environment.nix file (AVALONIA_GLOBAL_SCALE_FACTOR moved elsewhere)
- Moved android-tools from productivity to development packages
- Removed entertainment.nix package file (ryubing, lsfg-vk packages)
- Removed daed and v2rayn from productivity packages
- Updated clash-verge-rev to version 2.4.5 (stable release)
- Improved distrobox package organization with comments

### Fixed
- Fixed ZFS version pinning trace messages to use "FYI" prefix instead of "TODO"
- Added remote tag deletion to create-tags.sh script

## [v2026.02.04.01] - 2026-02-04

### Added
- Added build tools (gnumake, cmake, gcc, ninja) to development packages
- Added openssl to development packages
- Added remmina to productivity packages (later removed in v2026.02.05.01)

### Changed
- Reorganized unixtools packages, moving development tools to development.nix
- Removed hardinfo2, just, nixfmt, freerdp, and network tools from unixtools
- Moved remote access tools (proxychains-ng, sshpass, android-tools) to productivity

## [v2026.02.03.01] - 2026-02-03

### Added
- Created comprehensive shell configuration system with separate login, interactive, and all-shell contexts
- Added UV_CACHE_DIR automatic configuration based on current filesystem
- Added px() proxy toggle function with configurable proxy URL
- Added yazi directory change function (y command)
- Added tmux configuration for user 'u' with custom prefix (C-o)
- Added tmux configuration symlink for nas user
- Created nixos user configuration with SSH authorized keys
- Added serial console support for savior ISO with autologin
- Added mergeAttrsList helper function to rabit-lib

### Changed
- Refactored shell.nix module with proper separation of bash/zsh configuration contexts
- Improved ISO image configuration with GRUB menu specialisations (GNOME/XFCE/CLI)
- Updated nixos user home-manager state version to 26.05
- Consolidated private-module imports to use nixosModules.all
- Enhanced nixos-generators module with better structure using mergeAttrsList
- Improved create-tags.sh script with better tag management and dry-run support

### Fixed
- Fixed shell environment variable handling across different shell contexts
- Fixed ISO image GRUB menu ordering with zzz_ prefix for CLI specialisation

