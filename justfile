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
check nix-args='':
  git add .
  nix flake check {{nix-args}}

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

# Build and activate the new configuration, and make it the boot default
[group('NixOS')]
build:
  nh os switch

# Rebuild NixOS configuration with nixos-rebuild *(deprecated)*
[group('NixOS')]
[confirm('This command is obsolete, please use `switch` command instead. are you really sure to run this?')]
rebuild-with-nixos-rebuild:
  sudo git -C /etc/nixos reset --hard
  sudo git -C /etc/nixos fetch --all
  sudo git -C /etc/nixos checkout "{{branch}}"
  sudo git -C /etc/nixos pull --rebase
  nixos-rebuild switch --show-trace --verbose --sudo
  cp /etc/nixos/*.lock .

# list generations
[group('NixOS')]
list-generations profile="system":
  [ "{{profile}}" == "system" ] && nixos-rebuild list-generations || nix-env --list-generations


# trim-generations *(deprecated)*
[confirm('This command is obsolete, please use `clean` command instead. are you really sure to run this?')]
[group('NixOS')]
trim-generations generations="3" days="3" profile="system":
  [ "{{profile}}" == "system" ] && sudo=sudo; \
  $sudo bash scripts/nixos-trim-generations.sh {{generations}} {{days}} {{profile}}

# interactively remove generations
[group('NixOS')]
remove-generation:
  nixos-rebuild list-generations ; \
  while read -p 'remove generation:' n; do \
    sudo nix-env -p /nix/var/nix/profiles/system --delete-generations "$n"; \
    nixos-rebuild list-generations; \
  done

# cleanup nix store
[group('NixOS')]
clean:
  nh clean all

# [obsolete] Activate the configuration (similar to rebuild)
[group('NixOS')]
[confirm('This command is obsolete, please use `rebuild` command instead. are you really sure to run this?')]
run:
  # This command is deprecated bacause nix-run does not keep git repo,
  # therefore system.configurationRevision will be empty in the generation we built.
  nix run
