# Like GNU `make`, but `just` rustier.
# https://just.systems/man/en/
# https://github.com/casey/just
# run `just` from this directory to see available commands

# Default command when 'just' is run without arguments
default:
  @just --list

# Update nix flake
[group('NixOS')]
update:
  nix flake update

# Lint nix files
[group('dev')]
lint:
  nix fmt

# Check nix flake
[group('dev')]
check:
  nix flake check

# Manually enter dev shell
[group('dev')]
dev:
  nix develop

# Install pre-commit hook
[group('dev')]
pre-commit-hook:
  sh ./scripts/install-pre-commit-hook.sh

version_hint_file := "nixos-version-hint.txt"
version_hint_skip_file := ".nixos-version-hint-skip"


# Update version hint file, set `skip` to skip check, set `reset` to restore last value
[group('dev')]
version-hint content:
  #!/usr/bin/env bash
  set -euxo pipefail

  if [ '{{content}}' == "skip" ]; then
    git restore --staged '{{version_hint_file}}'
    git restore '{{version_hint_file}}'
    touch '{{version_hint_skip_file}}'
  elif [ '{{content}}' == "reset" ]; then
    git restore --staged '{{version_hint_file}}'
    git restore '{{version_hint_file}}'
    rm -f '{{version_hint_skip_file}}'
  else
    rm -f '{{version_hint_skip_file}}'
    printf '{{content}}' > '{{version_hint_file}}'
    git add '{{version_hint_file}}'
  fi

branch := "$(git rev-parse --abbrev-ref HEAD)"

# Rebuild NixOS configuration
[group('NixOS')]
rebuild:
  sudo git -C /etc/nixos reset --hard
  sudo git -C /etc/nixos fetch --all
  sudo git -C /etc/nixos checkout "{{branch}}"
  sudo git -C /etc/nixos pull --rebase
  nixos-rebuild switch --show-trace --verbose --sudo
  cp /etc/nixos/*.lock .

# [obsolete] Activate the configuration (similar to rebuild)
[group('NixOS')]
[confirm('This command is obsolete, please use `rebuild` command instead. are you really sure to run this?')]
run:
  # This command is deprecated bacause nix-run does not keep git repo,
  # therefore system.configurationRevision will be empty in the generation we built.
  nix run
