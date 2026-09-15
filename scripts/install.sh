#!/usr/bin/env bash
#
# nixos-install-config — install the KnownRabbit NixOS config as a machine's
# first generation, starting from a live installer ISO.
#
# Partitioning, formatting and mounting are intentionally left to you. Before
# running this script, mount the target filesystems under --root (default
# /mnt) exactly as you want them recorded in hardware-configuration.nix. The
# ISO ships a hands-on manual at /etc/nixos-install-manual.md (and as
# INSTALL.html on the live desktop) describing the required and optional
# mountpoints.
#
# This script then:
#   1. clones (or reuses) the config flake at <root>/etc/nixos
#   2. scaffolds configurations/nixos/<host>/{default,configuration}.nix
#   3. runs nixos-generate-config to write hardware-configuration.nix
#   4. stages the new host so the flake (which only sees git-tracked files)
#      can evaluate it
#   5. runs nixos-install --flake <dir>#<host>
#
# The first generation uses the committed public shim for the private module,
# so it needs no credentials. Clone ./private and run `xc switch` after the
# first boot to pull the private module in.

set -euo pipefail

readonly DEFAULT_REPO_URL="https://github.com/ttimasdf/nixos-config"
readonly DEFAULT_ROOT="/mnt"
readonly DEFAULT_USER="nixos"
readonly DEFAULT_HOST_PLATFORM="x86_64-linux"

repo_url="$DEFAULT_REPO_URL"
repo_ref=""
root="$DEFAULT_ROOT"
host=""
user_name="$DEFAULT_USER"
host_platform="$DEFAULT_HOST_PLATFORM"
state_version=""
flake_dir=""
assume_yes=0
no_root_password=0
set_user_password=1

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGEEOF'
nixos-install-config — bootstrap a new host as its first generation.

Usage:
  nixos-install-config --host NAME [options]

Options:
  --host NAME             Host name; must match configurations/nixos/<NAME>. (required)
  --user NAME             Login user to configure. Default: nixos
  --root PATH             Target root, mounted. Default: /mnt
  --flake-dir PATH        Where to clone/reuse the config flake.
                          Default: <root>/etc/nixos
  --repo-url URL          Config flake to clone.
                          Default: https://github.com/ttimasdf/nixos-config
  --repo-ref REF          Branch or tag to clone (default: the repo default branch)
  --host-platform SYS     nixpkgs.hostPlatform for the new host. Default: x86_64-linux
  --state-version VER     system.stateVersion for the new host.
                          Default: detected from `nixos-version`
  --no-root-password      Do not let nixos-install prompt for a root password
  --no-user-password      Do not offer to set the login user's password
  -y, --yes               Assume yes for all confirmations (non-interactive)
  -h, --help              Show this help

Partitioning is not automated: mount the target filesystems under --root
before running this script. See the install manual for the mountpoints that
nixos-generate-config needs to see.
USAGEEOF
}

confirm() {
  if [ "$assume_yes" -eq 1 ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    die "confirmation required but stdin is not a terminal; pass --yes to proceed"
  fi
  local reply
  read -r -p "$1 [y/N] " reply
  case "$reply" in
    [yY] | [yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      [ "$#" -ge 2 ] || die "option --host requires a value"
      host="$2"
      shift 2
      ;;
    --user)
      [ "$#" -ge 2 ] || die "option --user requires a value"
      user_name="$2"
      shift 2
      ;;
    --root)
      [ "$#" -ge 2 ] || die "option --root requires a value"
      root="$2"
      shift 2
      ;;
    --flake-dir)
      [ "$#" -ge 2 ] || die "option --flake-dir requires a value"
      flake_dir="$2"
      shift 2
      ;;
    --repo-url)
      [ "$#" -ge 2 ] || die "option --repo-url requires a value"
      repo_url="$2"
      shift 2
      ;;
    --repo-ref)
      [ "$#" -ge 2 ] || die "option --repo-ref requires a value"
      repo_ref="$2"
      shift 2
      ;;
    --host-platform)
      [ "$#" -ge 2 ] || die "option --host-platform requires a value"
      host_platform="$2"
      shift 2
      ;;
    --state-version)
      [ "$#" -ge 2 ] || die "option --state-version requires a value"
      state_version="$2"
      shift 2
      ;;
    --no-root-password)
      no_root_password=1
      shift
      ;;
    --no-user-password)
      set_user_password=0
      shift
      ;;
    -y | --yes)
      assume_yes=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      [ "$#" -eq 0 ] || die "unexpected argument '$1'"
      ;;
    -*)
      die "unknown option '$1' (try --help)"
      ;;
    *)
      [ -n "$host" ] || die "unexpected argument '$1' (try --help)"
      die "unexpected argument '$1' (try --help)"
      ;;
  esac
done

# -- preflight ---------------------------------------------------------------

[ "$(id -u)" -eq 0 ] || die "must run as root (it writes to the target and calls nixos-install)"
[ -n "$host" ] || die "--host is required (e.g. --host myserver)"
[[ "$host" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "invalid host name '$host'"
[[ "$user_name" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "invalid user name '$user_name'"

for cmd in git nixos-install nixos-generate-config realpath; do
  command -v "$cmd" >/dev/null 2>&1 || die "required command '$cmd' not found in PATH"
done

root="$(realpath -e -- "$root" 2>/dev/null)" || die "install root '$root' does not exist"

if ! mountpoint -q -- "$root"; then
  warn "$root is not a mountpoint; nixos-install will install into whatever is mounted there."
  confirm "Continue with $root anyway?" || die "aborted"
fi

if ! mountpoint -q -- "$root/boot"; then
  warn "$root/boot is not a separate mountpoint."
  warn "On an EFI machine, mount the EFI System Partition at $root/boot first,"
  warn "otherwise it is not recorded and the bootloader cannot be installed."
  confirm "Continue without an ESP mounted at $root/boot?" || die "aborted"
fi

if [ -z "$state_version" ]; then
  state_version="$(nixos-version 2>/dev/null | sed -nE 's/^([0-9]+\.[0-9]+).*/\1/p' || true)"
  if [ -z "$state_version" ]; then
    state_version="26.11"
    warn "could not detect the NixOS release; defaulting system.stateVersion to $state_version"
  fi
fi

flake_dir="${flake_dir:-$root/etc/nixos}"
flake_dir="$(realpath -m -- "$flake_dir")"

log "host:          $host"
log "user:          $user_name"
log "install root:  $root"
log "flake dir:     $flake_dir"
log "repo:          $repo_url${repo_ref:+ (ref: $repo_ref)}"
log "state version: $state_version"

# -- step 1: clone or reuse the flake ---------------------------------------

if [ -d "$flake_dir/.git" ]; then
  log "reusing existing checkout at $flake_dir"
  if [ -n "$repo_ref" ]; then
    git -C "$flake_dir" fetch --depth=1 origin "$repo_ref"
    git -C "$flake_dir" checkout --detach FETCH_HEAD
  fi
elif [ -e "$flake_dir" ] && [ -n "$(ls -A -- "$flake_dir" 2>/dev/null || true)" ]; then
  die "$flake_dir exists but is not a git checkout; move it aside or pass --flake-dir"
else
  log "cloning $repo_url into $flake_dir"
  mkdir -p -- "$(dirname -- "$flake_dir")"
  if [ -n "$repo_ref" ]; then
    git clone --branch "$repo_ref" -- "$repo_url" "$flake_dir"
  else
    git clone -- "$repo_url" "$flake_dir"
  fi
fi

# -- step 2: scaffold the host ----------------------------------------------

host_dir="$flake_dir/configurations/nixos/$host"
host_rel="configurations/nixos/$host"
mkdir -p -- "$host_dir"

if [ ! -e "$host_dir/default.nix" ]; then
  log "writing $host_rel/default.nix"
  cat > "$host_dir/default.nix" <<'NIXEOF'
# See /modules/nixos/* for actual settings
# This file is just *top-level* configuration.
{ flake, ... }:

let
  inherit (flake.inputs) self nur private-module;
in
{
  imports = [
    nur.modules.nixos.default
    self.nixosModules.common
    private-module.nixosModules.all
    self.nixosModules.programs
    ./configuration.nix
  ];
}
NIXEOF
else
  log "keeping existing $host_rel/default.nix"
fi

if [ ! -e "$host_dir/configuration.nix" ]; then
  log "writing $host_rel/configuration.nix"
  cat > "$host_dir/configuration.nix" <<'NIXEOF'
# First-generation host scaffolded by `nixos-install-config`.
# Keep this minimal until the machine boots; add gui/secure-boot/etc. later.
{ flake
, config
, lib
, pkgs
, ...
}:

let
  inherit (flake.inputs) self;
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "__HOST_PLATFORM__";

  networking.hostName = "__HOST__";
  networking.networkmanager.enable = true;

  # Bootstrap bootloader. Switch to limine/secure-boot once the machine boots.
  # For a legacy BIOS install, replace this with your boot.loader.grub settings.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Login user; sourced from configurations/users/<name>.nix and
  # configurations/home/<name>/.
  rabit.nixos.myusers = [ "__USER__" ];

  # Remote access while you finish configuring the machine.
  services.openssh.enable = true;

  system.stateVersion = "__STATE_VERSION__";
}
NIXEOF
  sed -i \
    -e "s|__HOST__|$host|g" \
    -e "s|__USER__|$user_name|g" \
    -e "s|__HOST_PLATFORM__|$host_platform|g" \
    -e "s|__STATE_VERSION__|$state_version|g" \
    "$host_dir/configuration.nix"
else
  log "keeping existing $host_rel/configuration.nix"
fi

# -- step 3: generate the hardware configuration ----------------------------

log "scanning the filesystems mounted under $root"
nixos-generate-config --root "$root" --dir "$host_dir"

log "recorded by the scan:"
grep -E 'fileSystems\.|swapDevices|luks\.devices' "$host_dir/hardware-configuration.nix" || true

if ! grep -q 'fileSystems\."/boot"' "$host_dir/hardware-configuration.nix"; then
  warn "no fileSystems.\"/boot\" entry was recorded; an EFI machine will not boot without one."
fi

if [ "$assume_yes" -eq 0 ] && [ -t 0 ]; then
  printf '\n--- %s ---\n' "$host_rel/hardware-configuration.nix"
  cat "$host_dir/hardware-configuration.nix"
  printf -- '--- end ---\n\n'
  confirm "Proceed with nixos-install for '$host'?" || die "aborted"
fi

# -- step 4: make the new host visible to the flake -------------------------

log "staging $host_rel so the flake can evaluate it"
git -C "$flake_dir" add -- "$host_rel"

# -- step 5: install ---------------------------------------------------------

install_args=(--root "$root" --flake "$flake_dir#$host")
if [ "$no_root_password" -eq 1 ]; then
  install_args+=(--no-root-password)
fi

log "running: nixos-install ${install_args[*]}"
nixos-install "${install_args[@]}"

# -- post-install ------------------------------------------------------------

if [ "$set_user_password" -eq 1 ] && [ -t 0 ]; then
  if confirm "Set a login password for '$user_name' now?"; then
    if ! nixos-enter --root "$root" -c "passwd $user_name"; then
      warn "could not set a password; set it after boot with: passwd $user_name"
    fi
  fi
fi

cat <<EOF

==> First generation for '$host' is installed.

After rebooting into the new system:
  1. Log in as '$user_name'.
  2. Pull in the private module (only if you have access to it):
       git clone git@github.com:ttimasdf/nixos-config-private /etc/nixos/private
       git -C /etc/nixos submodule update --init --recursive
  3. Switch to the full configuration:
       cd /etc/nixos
       sudo nixos-rebuild switch --flake .#\$(hostname) \\
         --override-input private-module path:./private \\
         --override-input known-rabbit-packages path:./public-packages
  4. Commit the scaffolded host so it stays part of the flake:
       git -C /etc/nixos add configurations/nixos/$host
EOF
