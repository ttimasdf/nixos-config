[![xc compatible](https://xcfile.dev/badge.svg)](https://xcfile.dev)

# KnownRabbit NixOS Config

A modular, multi-host NixOS configuration with private module support so you can ditch agenix.

## Hosts

- **viscacha**: Personal config for [@ttimasdf](https://github.com/ttimasdf)
- **MNIX**: Personal config for [@Tardis07](https://github.com/Tardis07)
- **savior**: Minimal config for building ISOs (system rescue & benchmarking)
- **basenji**: NAS virtual machine with ZFS storage, Cockpit web management, Samba file sharing, and Podman containers

## Features

- **Version Hints**: Custom suffixes for system version numbers in boot menus and ISO filenames.
- **Private Module**: Supports separation of public and private configuration via a private module; a [module template](https://github.com/ttimasdf/nixos-config-module) is available for reference (see [Using this config](#using-this-config)).
- **Modular Design**: Unifies [NixOS](https://nixos.org/), [nix-darwin](https://github.com/LnL7/nix-darwin), and [home-manager](https://github.com/nix-community/home-manager) configuration in a single flake using [nixos-unified](https://github.com/srid/nixos-unified).
- **Auto-wiring**: Automatically discovers and imports configurations into the final flake output from the directory structure, see the chapter [Structure](#structure) below.
- **Image Building**: Build ISO/VM/Cloud images from any machine config using `nh os build-image` (e.g., `nh os build-image --image-variant iso-xfce .#savior`). One installer variant per host carries that host's closure, so it can be installed offline: `--image-variant iso-xfce-install-<host>`.
- **CI**: GitHub Actions builds every host, local package, and `public-packages` package; licensed sources such as `ida-pro` are substituted from a private Attic cache instead of being published. See [docs/ci.md](docs/ci.md).

## Using this config

You can clone or fork this repository as a configuration template. Reusable packages, portable overlays, and package-specific modules are published separately in [`ttimasdf/nix-packages`](https://github.com/ttimasdf/nix-packages).

To include this module in your NixOS config, you need to provide a `private-module` input. This allows for separation of public and private configuration details.

For public users who want to use this config as a base or reference without access to the private repository, please use the [public module template](https://github.com/ttimasdf/nixos-config-module) in place of the private module.

This repository's own `private-module` input already points at that public template, so the committed flake evaluates without private access. Local tasks point the input at the gitignored `./private` checkout instead whenever that checkout exists (`xc switch`, `xc test`, ...), as shown in [Tasks](#tasks).

Add the following to your `flake.nix` inputs:

```nix
inputs = {
  ttimasdf-nixos-config = {
    url = "github:ttimasdf/nixos-config";
    # Follow the private-module input to the public module template
    inputs.private-module.follows = "private-module";
  };

  # The public module template for the private module
  private-module = {
    url = "github:ttimasdf/nixos-config-module";
  };
};
```

For packages and overlays, consume the dedicated flake directly:

```nix
inputs.known-rabbit-packages = {
  url = "github:ttimasdf/nix-packages";
  inputs.nixpkgs.follows = "nixpkgs";
};

# In a NixOS module:
nixpkgs.overlays = [
  inputs.known-rabbit-packages.overlays.default
  # Opt-in existing-package overrides:
  inputs.known-rabbit-packages.overlays.kscreen
];
```

## Structure

The repository is organized into the following main directories:

-   `flake.nix`: The main Nix flake file, defining inputs and outputs for the entire configuration.
-   `packages/`: Local packages that cannot be published, currently private-source packages.
-   `known-rabbit-packages` input: Public packages, portable overlays, and package-specific NixOS modules.
-   `configurations/`: Contains machine-specific NixOS and Home Manager configurations.
    -   `configurations/home/<user>.nix`: Defines Home Manager configurations for a specific user. The presence of such a file automatically registers `<user>` for both Home Manager and system-level user configurations. A directory like `configurations/home/<user>/default.nix` is also supported.
    -   `configurations/nixos/<hostname>/`: NixOS configurations for different machines.
    -   `configurations/users/<user>.nix`: Provides system-level user configurations (for user groups, system permissions) for users defined in `configurations/home/`. A directory like `configurations/users/<user>/default.nix` is also supported.
-   `modules/`: Reusable Nix modules for various system and user settings.
    -   `modules/home/`: Home Manager modules.
    -   `modules/nixos/`: NixOS modules, including common settings, GUI environments, and specific features like `label-suffix`.
    -   `modules/flake/`: Flake modules for Nix config debugging and package development.
-   `README.md`: Contains `xc` task definitions for common development and NixOS management tasks (see Tasks section).
-   `nixos-version-hint.txt`: A file to specify a custom suffix for the NixOS system label.

### Flake Outputs

Each of the directories are wired to the corresponding flake output, as indicated in the below table:


| Directory                                     | Flake Output                                                    |
| --------------------------------------------- | --------------------------------------------------------------- |
| `configurations/nixos/foo.nix`<sup>(1)</sup>  | `nixosConfigurations.foo`                                       |
| `configurations/darwin/foo.nix`<sup>(1)</sup> | `darwinConfigurations.foo`                                      |
| `configurations/home/foo.nix`<sup>(1)</sup>   | `legacyPackages.${system}.homeConfigurations.foo`<sup>(2)</sup> |
| `modules/nixos/foo.nix`                       | `nixosModules.foo`                                              |
| `modules/darwin/foo.nix`                      | `darwinModules.foo`                                             |
| `modules/flake/foo.nix`                       | `flakeModules.foo`                                              |

(1): This path could as well be `configurations/nixos/foo/default.nix`. Likewise for other output types.

(2): Why `legacyPackages`? Because, creating a home-manager configuration [requires `pkgs`](https://github.com/srid/nixos-unified/blob/47a26bc9118d17500bbe0c4adb5ebc26f776cc36/nix/modules/flake-parts/lib.nix#L97). See <https://github.com/nix-community/home-manager/issues/3075>

Public package outputs are provided by the separate `nix-packages` flake. Local package files are only injected into host `pkgs` through the local overlay.

### Home Manager configurations: `configurations/home/`

The [`modules/nixos/common/myusers.nix`](modules/nixos/common/myusers.nix) module automatically discovers users by listing all `.nix` files (e.g., `configurations/home/<user>.nix` or `configurations/home/<user>/default.nix`) in `configurations/home/`. These discovered users are used as the default for the `rabit.nixos.myusers` option. This option can also be manually specified to define the list of users. For each user in `rabit.nixos.myusers`, their respective Home Manager configuration is loaded into `config.home-manager.users.<user>`.


In all cases, home manager configuration is loaded by [nixos-unified autowire](https://github.com/srid/nixos-unified/blob/1f8ab18330354d2305a0d793da58a6ef83e2857c/nix/modules/flake-parts/autowire.nix#L60-L63) and exposed into flake `flake.perSystem.legacyPackages.homeConfigurations`,

### NixOS configurations: `configurations/nixos/`

`configurations/nixos` is loaded by [nixos-unified autowire](https://github.com/srid/nixos-unified/blob/1f8ab18330354d2305a0d793da58a6ef83e2857c/nix/modules/flake-parts/autowire.nix#L38-L41) into `flake.nixosConfigurations` via `forAllNixFiles`.

#### common module: `configurations/nixos/common/`

`configurations/nixos/common` includes some common modules shared by nixos and nix-darwin. Do not add NixOS-specific config into this module.


### System-level user configurations: `configurations/users/`

For each user in `rabit.nixos.myusers` (which defaults to users automatically discovered from `configurations/home/`, but can also be manually specified), their corresponding system-level user configuration (`configurations/users/<user>.nix` or `configurations/users/<user>/default.nix`) is loaded by [`modules/nixos/common/myusers.nix`](modules/nixos/common/myusers.nix) into `config.users.users.<user>`.

See [NixOS Options Search: `users.user`](https://search.nixos.org/options?channel=unstable&query=users.user) for available options.


### Secrets (SOPS)

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix): they are stored **encrypted** in `private/secrets/` (safe for the world-readable Nix store) and decrypted at boot into `/run/secrets` (tmpfs) using each host's SSH host key (ed25519 → age via `ssh-to-age`). Host files are encrypted only to that host plus your personal editing key, so a compromised host cannot read other hosts' secrets. Creation rules live in `private/.sops.yaml`.

The devshell (`nix develop` / direnv) ships `sops` + `ssh-to-age` and sets `SOPS_AGE_KEY_FILE` to the dedicated identity `~/.config/sops/age/nixos-config.txt`.

**Editing secrets** (from the devshell):

```bash
sops private/secrets/brisling.yaml          # $EDITOR opens decrypted; re-encrypts on save
sops -d private/secrets/basenji/syncthing-key.pem   # decrypt to stdout (e.g. for rotation)
```

**Enrolling a host** — run on the host itself, then paste the key into `private/.sops.yaml` and re-encrypt the affected files:

```bash
nix shell nixpkgs#ssh-to-age -c ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub
# then, from this repo's devshell:
sops updatekeys private/secrets/<host-file-or-dir>/*
```

> A host must be enrolled (and its secret files re-encrypted with `sops updatekeys`) **before** deploying a config that declares its `sops.secrets`, otherwise decryption fails at boot.

**First deploy / fresh installs** — the encrypted files are baked into the store before first boot, but the SSH host key only exists after. Depending on the install path:

- *Installer flow* (`nixos-install`): pre-seed the target's host key before installing, then enroll it, then install (order matters — `nixos-install` snapshots the secret files into the store):
  ```bash
  # in the installer, target mounted at /mnt:
  ssh-keygen -t ed25519 -N "" -f /mnt/etc/ssh/ssh_host_ed25519_key -C root@<host>
  # workstation: convert the printed .pub with ssh-to-age, fill private/.sops.yaml,
  # sops updatekeys private/secrets/<host>..., THEN: nixos-install --flake .#<host>
  ```
- *Image-based hosts* (e.g. basenji Proxmox image): boot the image un-enrolled — host keys are generated on first boot, `sops-install-secrets` and only the secret-dependent services fail while the system itself boots fine — then enroll, `sops updatekeys`, and rebuild.
- *Reinstall-invariant hosts*: keep a dedicated per-host ed25519 keypair in a password manager, `install -m600` it into the target's `/etc/ssh/` at install time; the host keeps the same age identity (and SSH identity) across reinstalls, no re-encryption ever needed.

  Never bake host keys into built images — the private key would be world-readable in the image's nix store.

Hosts enrolled so far: `viscacha`. Pending: `basenji`, `brisling`, `MNIX`, `wsl` (see TODOs in `private/.sops.yaml`). `savior` (rescue ISO) is excluded — it has no persistent host identity.

Limitation: sops decrypts after `local-fs.target`, so disk-encryption keyfiles (e.g. the BitLocker `.BEK` files in `/root/.secrets/`) cannot be sops-managed and stay as plain root-owned files.


### Version Hint Feature

The version hint feature allows you to append a custom string to your NixOS system label, which is useful for distinguishing between different builds or versions.

**How to Use:**

1.  **Create the Version Hint File**: In the root of this repository, create a file named `nixos-version-hint.txt`.
2.  **Add Your Version Hint**: Open `nixos-vers`ion-hint.txt` and add your desired version hint. For example:
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
- **Reset Version Hint**: Use `xc version-hint reset` to restore the version hint to the last committed value
- **Skip via Command**: Use `xc version-hint skip` to create the skip file automatically

This feature is implemented via the [`modules/nixos/common/version-hint.nix`](modules/nixos/common/version-hint.nix) module and validated by [`scripts/pre-commit-nixos-version-hint.sh`](scripts/pre-commit-nixos-version-hint.sh).


## Tasks

The tasks in this section are compatible with the [xc task runner](https://xcfile.dev/). You can execute any of these commands simply by running `xc <task-name>`, e.g., `xc build`.

### update

Update nix flake

```bash
nix flake update
```

### build-host

Build a specific host configuration

Inputs: HOST

```bash
[ -d ./private ] && OVERRIDE_PRIVATE_ARGS="--override-input private-module path:./private"
nh os build --hostname $HOST -- \
  --override-input known-rabbit-packages path:./public-packages \
  $OVERRIDE_PRIVATE_ARGS
```


### build-package

Build a specific package

`build-package` and `build-host` are the two tasks that point
`known-rabbit-packages` at the local `public-packages` checkout, so a package
change can be tried before it is pushed and the parent lockfile is updated.
Every other task uses the revision pinned in `flake.lock`.

Inputs: PACKAGE

```bash
[ -d ./private ] && OVERRIDE_PRIVATE_ARGS="--override-input private-module path:./private"
echo $HOST
nix build \
  --override-input known-rabbit-packages path:./public-packages \
  $OVERRIDE_PRIVATE_ARGS \
  .#nixosConfigurations.${HOST:-$(hostname)}.pkgs.rustdesk-flutter-unattended-wayland
```

### switch

Build and activate the new configuration, and make it the boot default

```bash
[ -d ./private ] && OVERRIDE_PRIVATE_ARGS="--override-input private-module path:./private"
nh os switch -k -K -- $OVERRIDE_PRIVATE_ARGS
```

### build-xfce-iso

Build the plain xfce-iso for [`savior`](configurations/nixos/savior). This is
my usual system rescue CD: it carries no host closure.

```bash
[ -d ./private ] && OVERRIDE_PRIVATE_ARGS="--override-input private-module path:./private"
nh os build-image -o result --image-variant iso-xfce .#savior -- $OVERRIDE_PRIVATE_ARGS
```

`nh` puts the result link in a temporary directory unless told otherwise, hence
`-o result` (`nixos-rebuild build-image` used to write `./result`); the link
doubles as the garbage-collection root for the image.

### build-xfce-iso-with

Build an xfce-iso that additionally carries one host's closure, so that host can
be built or installed from the live ISO with no network access. There is one
variant per host, `iso-xfce-install-<host>`, for every directory under
`configurations/nixos/`.

Inputs: HOST

```bash
[ -d ./private ] && OVERRIDE_PRIVATE_ARGS="--override-input private-module path:./private"
nh os build-image -o result --image-variant "iso-xfce-install-$HOST" .#savior -- $OVERRIDE_PRIVATE_ARGS
```

For example, `xc build-xfce-iso-with viscacha`. To list the available variants,
run `nix eval .#nixosConfigurations.savior.config.image.modules --apply 'm: builtins.filter (n: builtins.match "iso-xfce-install-.*" n != null) (builtins.attrNames m)'`.

Boot the resulting ISO and run `nixos-rabit-install --host <host>`; see the
[install manual](docs/install.md).

### install

Bootstrap a new host as its first generation. The [install manual](docs/install.md)
covers the required and optional mountpoints; this task runs the same
`nixos-rabit-install` helper that ships on the ISO, against a target root.

Inputs: HOST

```bash
sudo scripts/nixos-rabit-install.sh \
  --host "$HOST" \
  --root "${ROOT:-/mnt}" \
  --user "${NIXOS_USER:-nixos}"
```

### build-nas-vm

```bash
[ -d ./private ] && OVERRIDE_PRIVATE_ARGS="--override-input private-module path:./private"
nh os build-image -o result --image-variant proxmox .#basenji -- $OVERRIDE_PRIVATE_ARGS
```

### list

List system generations

```bash
nh os info
```

### list-user

List user profile generations

Inputs: PROFILE

```bash
nix-env --list-generations $@
```

### clean

Cleanup nix store

```bash
nh clean all
```

### test

Build and activate the new configuration, and make it the boot default

```bash
[ -d ./private ] && OVERRIDE_PRIVATE_ARGS="--override-input private-module path:./private"
nh os build $@ -- $OVERRIDE_PRIVATE_ARGS
```

### version-hint

Update version hint file, set `skip` to skip check, set `reset` to restore last value

Inputs: CONTENT

```bash
#!/usr/bin/env bash
set -euxo pipefail

version_hint_file="nixos-version-hint.txt"
version_hint_skip_file=".nixos-version-hint-skip"

if [ "$CONTENT" == "skip" ]; then
  git restore --staged "$version_hint_file"
  git restore "$version_hint_file"
  touch "$version_hint_skip_file"
elif [ "$CONTENT" == "reset" ]; then
  git restore --staged "$version_hint_file"
  git restore "$version_hint_file"
  rm -f "$version_hint_skip_file"
else
  rm -f "$version_hint_skip_file"
  printf '%s' "$CONTENT" > "$version_hint_file"
  git add "$version_hint_file"
fi
```


### remove-generation

Interactively remove generations

```bash
nh os info
while read -p 'remove generation:' n; do
  sudo nix-env -p /nix/var/nix/profiles/system --delete-generations "$n"
  nh os info
done
```

### trim-generations

> [!WARNING]
> This command is obsolete, please use `clean` command instead.

Trim old NixOS generations for a given profile with optional arguments.

Inputs: GENERATIONS, DAYS, PROFILE

- **GENERATIONS** — Number of generations to keep (default: `3`)
- **DAYS** — Number of days of system history to trim to (default: `3`)
- **PROFILE** — Name of the Nix profile (default: `system`)

```bash
# trim-generations: Trim old NixOS generations (obsolete; use 'clean' instead).
# Usage: trim-generations [GENERATIONS] [DAYS] [PROFILE]
# Defaults: GENERATIONS=3, DAYS=3, PROFILE=system

if [ "$PROFILE" = "system" ]; then
  sudo=sudo
else
  sudo=
fi

$sudo bash scripts/nixos-trim-generations.sh "$GENERATIONS" "$DAYS" "$PROFILE"
```


### lint

Lint nix files

```bash
nix fmt
```

### check

Check nix flake

```bash
[ -d ./private ] && OVERRIDE_PRIVATE_ARGS="--override-input private-module path:./private"
git add .
nix flake check $OVERRIDE_PRIVATE_ARGS $@
```

### dev

Manually enter dev shell

```bash
nix develop
```

### push-cache

Push the last build result (or an explicit store path) to the private Attic
cache that CI substitutes from. This is how licensed package sources such as
`ida-pro` reach GitHub Actions without being published; see
[the CI documentation](docs/ci.md).

Inputs: PATH

```bash
attic push "${ATTIC_CACHE:-nixos-config}" "${PATH:-$(readlink -f result)}"
```

### pre-commit-hook

Install pre-commit hook

```bash
sh ./scripts/install-pre-commit-hook.sh
```

## Developing Packages and Overlays

Public packages and portable overlays are maintained in [`ttimasdf/nix-packages`](https://github.com/ttimasdf/nix-packages). That repository provides direct flake package outputs, a NUR-compatible `default.nix`, portable overlays, and package-specific NixOS modules.

Hosts import published modules explicitly through `known-rabbit-packages.nixosModules.<name>`. `known-rabbit-packages.nixosModules.all` is available when a host intentionally wants the complete published module set. The reference configuration trusts and applies every distinct overlay exported by `known-rabbit-packages`; the local [`modules/nixos/programs/default.nix`](modules/nixos/programs/default.nix) scaffold only collects custom program modules defined beside it.

The local `packages/` directory is reserved for packages that cannot be published, such as private-source software. Direct package files and directories containing `default.nix` are added to host package sets by [`modules/nixos/common/nixpkgs-overlays.nix`](modules/nixos/common/nixpkgs-overlays.nix).
