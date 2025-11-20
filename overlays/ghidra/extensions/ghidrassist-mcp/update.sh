#!/usr/bin/env bash

set -ex

# updateScript should be run in flake root
pushd "$NH_FLAKE"

$(nix build --print-out-paths .#nixosConfigurations.viscacha.pkgs.ghidra-custom-extensions.ghidrassist-mcp.mitmCache.updateScript)
