# Installing a new host from this ISO

This ISO is built from the `savior` configuration (`xc build-xfce-iso`). It
boots into an XFCE live session as user `nixos` (no password) and carries the
`nixos-rabit-install` helper.

This manual is on the live desktop as `INSTALL.html` (rendered) and
`INSTALL.md` (source), and at `/etc/nixos-install-manual.{html,md}`.

The installer deliberately does **not** partition or format disks. You pick
the layout, mount it, and the script records exactly what it sees.

The ISO also carries this config's flake and every input it needs, so a host
can be installed with no network access at all.

## 1. Partition, format, mount

`nixos-generate-config` describes the target by inspecting what is *mounted*
under the install root (`/mnt`) at the moment it runs. Kernel modules and
LUKS containers are detected from the running hardware and the open mappers.

| Mountpoint       | Required?          | Notes                                                                                                                                   |
| ---------------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| `/mnt` (root `/`) | **Required**       | The root filesystem. Without it there is nothing to install into.                                                                       |
| `/mnt/boot`      | **Required on EFI** | The EFI System Partition (vfat). Recorded as `fileSystems."/boot"`; the bootloader is installed here. Mount the ESP at `/boot`, **not** `/boot/efi`. |
| `/mnt/home`      | Optional           | Only recorded if you mount a separate `/home`.                                                                                          |
| `/mnt/nix`       | Optional           | Only recorded if you mount a separate `/nix`. Recommended, so snapshots of `/` stay small.                                              |
| `/mnt/var/...`   | Optional           | Separate `/var`, `/var/log`, `/var/lib` subvolumes are recorded individually.                                                           |
| swap             | Optional           | Active **partition** swap (via `swapon`) is recorded as `swapDevices`. Swap *files* and `zram` are intentionally skipped.                |

Rules of thumb:

- Anything you do **not** mount is not recorded. Add it to
  `hardware-configuration.nix` or `configuration.nix` afterwards.
- LUKS containers are detected: every open `cryptsetup` mapper becomes a
  `boot.initrd.luks.devices."<mapper-name>"` entry, so keep mapper names
  meaningful (`nixos-root`, `cryptswap`, ...).
- Btrfs subvolumes are detected from the current mount (`subvol=`), and vfat
  `fmask`/`dmask` options are preserved.
- Re-run `nixos-generate-config` (or the installer) any time your mounts
  change.

### Format and mount

Partition the disk however you like (`parted`, `fdisk`, ...), then fill in
your own partition names below and run it. LUKS is optional: comment the block
out for a plain install, and the rest works unchanged.

```bash
# Fill these in from `lsblk`.
esp=/dev/nvme0n1p1    # EFI System Partition (vfat)
root=/dev/nvme0n1p2   # holds /

# Optional: encrypt the root partition. Skip this block for a plain install.
cryptsetup luksFormat "$root"
cryptsetup open "$root" nixos-root   # any name; becomes boot.initrd.luks.devices."<name>"
root=/dev/mapper/nixos-root

# Format and mount.
mkfs.fat -F 32 -n BOOT "$esp"
mkfs.ext4 -L nixos "$root"
mount "$root" /mnt
mkdir -p /mnt/boot
mount "$esp" /mnt/boot
```

If you prefer Btrfs with separate `/`, `/home` and `/nix`, replace the ext4
line and the mounts above with:

```bash
mkfs.btrfs -L nixos "$root"
mount "$root" /mnt
btrfs subvolume create /mnt/root /mnt/home /mnt/nix
umount /mnt
opts="compress=zstd,noatime"
mount -o "subvol=root,$opts" "$root" /mnt
mkdir -p /mnt/{home,nix,boot}
mount -o "subvol=home,$opts" "$root" /mnt/home
mount -o "subvol=nix,$opts" "$root" /mnt/nix
mount "$esp" /mnt/boot
```

To include swap, create a swap partition, `mkswap` it and `swapon` it before
running the installer — only active partition swap is recorded. Encrypted swap
works the same way (`cryptsetup luksFormat` + `cryptsetup open <part> cryptswap`
+ `swapon /dev/mapper/cryptswap`). zram and swap files are configured in
`configuration.nix` instead.

## 2. Run the installer

```bash
nixos-rabit-install --host "${HOST}" --user u
```

It places the config flake at `/mnt/nixos-config` (copied from the ISO when
present, otherwise cloned), scaffolds `configurations/nixos/<host>/`, writes
`hardware-configuration.nix`, prints it, and asks for confirmation before
installing — the prompt reminds you that `configuration.nix` can still be
edited. Pass `--yes` to skip the confirmation.

### Offline installs

The ISO's `nixos-rabit-install` is preconfigured with the flake and all of its
inputs, which live in the store. It copies the baked flake instead of cloning,
pins the inputs that were overridden at ISO build time with `--override-input`
(the rest resolve from the baked lock), and disables binary substituters, so the
whole install runs with no network. Use `--repo-url` to force a git clone, or
`--offline`/`--online` to override the mode.

Useful flags:

- `--host NAME` (required) — must match `configurations/nixos/<NAME>`.
- `--user NAME` — which user from `configurations/home/` to configure.
  Default `nixos`, a minimal profile that is a safe bootstrap; switch to your
  real user afterwards.
- `--root PATH` — install root, default `/mnt`.
- `--flake-dir PATH` — where to put the flake, default `<root>/nixos-config`.
- `--repo-url URL`, `--repo-ref REF` — clone a fork or a specific branch/tag.
- `--state-version VER` — override the auto-detected `system.stateVersion`
  (taken from the running ISO's `nixos-version`).
- `--no-root-password`, `--no-user-password` — skip the corresponding prompts.
- `-y, --yes` — non-interactive; assumes yes for every confirmation.

When the flake is a git checkout, the script stages
`configurations/nixos/<host>/` with `git add` before installing, because such
a flake only sees tracked files.

## 3. First boot

The first generation imports the committed public shim for the private module,
not your private checkout, so it needs no credentials. On the installed
system:

```bash
git clone git@github.com:ttimasdf/nixos-config-private /nixos-config/private
git -C /nixos-config submodule update --init --recursive

cd /nixos-config
sudo nixos-rebuild switch --flake ".#$(hostname)" \
  --override-input private-module path:./private \
  --override-input known-rabbit-packages path:./public-packages
```

Commit `configurations/nixos/<host>/` when you are happy with it.

### Enabling Secure Boot

The scaffold boots with systemd-boot. To move to the signed Limine setup, put
the firmware in Setup Mode and import the module — the first rebuild generates
the signing keys and enrolls them for you.

#### 1. Put the firmware in Setup Mode

Reboot into firmware setup (`Del`, `F2` or `Esc`) and reset/clear the Secure
Boot keys. Secure Boot must be off while keys are enrolled.

#### 2. Import the module

- `configurations/nixos/<host>/default.nix`: add
  `self.nixosModules.secure-boot` to `imports`.
- `configurations/nixos/<host>/configuration.nix`: remove
  `boot.loader.systemd-boot.enable = true;` — the module force-disables it and
  enables Limine. Keep `boot.loader.efi.canTouchEfiVariables = true;`.

#### 3. Rebuild

Bootloader installation generates the keys in `/var/lib/sbctl`, signs Limine
with them and enrolls them via `sbctl enroll-keys --microsoft
--firmware-builtin`. Microsoft's keys are included so option ROMs, firmware
updates and any Windows install keep working.

```bash
cd /nixos-config
sudo nixos-rebuild switch --flake ".#$(hostname)" \
  --override-input private-module path:./private \
  --override-input known-rabbit-packages path:./public-packages
```

#### 4. Re-enable Secure Boot

Turn Secure Boot back on in firmware setup, reboot, then verify.

```bash
sbctl status   # Secure Boot: enabled
sbctl verify   # binaries on the ESP are signed
```

Notes:

- Keys live in `/var/lib/sbctl`, never in the Nix store. Because
  `modules/nixos/secure-boot.nix` sets `autoGenerateKeys = true` and
  `autoEnrollKeys.enable = true`, bootloader installation creates them and
  enrolls them; hosts that already have keys keep them. Enrollment only
  succeeds while the firmware is in Setup Mode.
- `autoEnrollKeys.extraArgs` defaults to `--microsoft --firmware-builtin`.
  Override it if your firmware needs different arguments, or set it to `[ ]`
  to enroll only your own keys.
- Back up `/var/lib/sbctl/keys`. Losing them means returning to Setup Mode and
  enrolling again.
- After switching, confirm the firmware boot order points at Limine (the
  `limine` EFI entry), not the old systemd-boot entry.

## Troubleshooting

- **"flake does not provide nixosConfigurations.&lt;host&gt;"** — the host files
  were not staged. Flakes in a git checkout only see tracked files:
  `git -C /nixos-config add configurations/nixos/<host>`.
- **Bootloader fails to install** — no ESP mounted at `/mnt/boot`. Mount it and
  re-run; `hardware-configuration.nix` must contain `fileSystems."/boot"`.
- **The machine will not boot after install** — check `boot.loader` in the
  scaffolded `configuration.nix`. It defaults to systemd-boot; a legacy BIOS
  install needs `boot.loader.grub` instead.
- **A filesystem is missing from the config** — it was not mounted when the
  scan ran. Mount it and re-run `nixos-rabit-install` (or
  `nixos-generate-config --root /mnt --dir /mnt/nixos-config/configurations/nixos/<host>`).
