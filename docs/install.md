# Installing a new host from this ISO

This ISO is built from the `savior` configuration (`xc build-xfce-iso`). It
boots into an XFCE live session as user `nixos` (no password) and carries the
`nixos-install-config` helper.

This manual is on the live desktop as `INSTALL.html` (rendered) and
`INSTALL.md` (source), and at `/etc/nixos-install-manual.{html,md}`.

The installer deliberately does **not** partition or format disks. You pick
the layout, mount it, and the script records exactly what it sees.

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

### Worked example: LUKS + Btrfs, matching `viscacha`

```bash
# Adjust the device names. Run `lsblk` first.
dev=/dev/nvme0n1

# 1. GPT layout: p1 = ESP, p2 = root (LUKS)
parted -s "$dev" mklabel gpt
parted -s "$dev" mkpart ESP fat32 1MiB 1GiB
parted -s "$dev" set 1 esp on
parted -s "$dev" mkpart root 1GiB 100%

# 2. EFI System Partition
mkfs.fat -F 32 -n BOOT "${dev}p1"

# 3. LUKS container + Btrfs subvolumes
cryptsetup luksFormat "${dev}p2"
cryptsetup open "${dev}p2" nixos-root
mkfs.btrfs -L nixos /dev/mapper/nixos-root

mount /dev/mapper/nixos-root /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
umount /mnt

# 4. Mount exactly what you want recorded, root first
opts="compress=zstd,noatime"
mount -o "subvol=root,$opts" /dev/mapper/nixos-root /mnt
mkdir -p /mnt/{home,nix,boot}
mount -o "subvol=home,$opts" /dev/mapper/nixos-root /mnt/home
mount -o "subvol=nix,$opts" /dev/mapper/nixos-root /mnt/nix
mount "${dev}p1" /mnt/boot
```

For a swap partition, `mkswap` and `swapon` it before installing so it lands
in the hardware config. For an encrypted swap, create and open it (for example
`cryptswap`) before installing as well.

## 2. Run the installer

```bash
nixos-install-config --host myserver --user u
```

It clones the config flake into `/mnt/etc/nixos`, scaffolds
`configurations/nixos/<host>/`, writes `hardware-configuration.nix`, prints
it for review, and runs `nixos-install`.

Useful flags:

- `--host NAME` (required) — must match `configurations/nixos/<NAME>`.
- `--user NAME` — which user from `configurations/home/` to configure.
  Default `nixos`, a minimal profile that is a safe bootstrap; switch to your
  real user afterwards.
- `--root PATH` — install root, default `/mnt`.
- `--flake-dir PATH` — checkout location, default `<root>/etc/nixos`.
- `--repo-url URL`, `--repo-ref REF` — clone a fork or a specific branch/tag.
- `--state-version VER` — override the auto-detected `system.stateVersion`
  (taken from the running ISO's `nixos-version`).
- `--no-root-password`, `--no-user-password` — skip the corresponding prompts.
- `-y, --yes` — non-interactive; assumes yes for every confirmation.

The script stages `configurations/nixos/<host>/` with `git add` before
installing, because a flake in a git checkout only sees tracked files.

## 3. First boot

The first generation imports the committed public shim for the private module,
not your private checkout, so it needs no credentials. On the installed
system:

```bash
git clone git@github.com:ttimasdf/nixos-config-private /etc/nixos/private
git -C /etc/nixos submodule update --init --recursive

cd /etc/nixos
sudo nixos-rebuild switch --flake ".#$(hostname)" \
  --override-input private-module path:./private \
  --override-input known-rabbit-packages path:./public-packages
```

Commit `configurations/nixos/<host>/` when you are happy with it. Enable the
`secure-boot` module (Limine + `sbctl`) only after the machine boots and you
have generated and enrolled keys.

## Troubleshooting

- **"flake does not provide nixosConfigurations.&lt;host&gt;"** — the host files
  were not staged. Flakes in a git checkout only see tracked files:
  `git -C /etc/nixos add configurations/nixos/<host>`.
- **Bootloader fails to install** — no ESP mounted at `/mnt/boot`. Mount it and
  re-run; `hardware-configuration.nix` must contain `fileSystems."/boot"`.
- **The machine will not boot after install** — check `boot.loader` in the
  scaffolded `configuration.nix`. It defaults to systemd-boot; a legacy BIOS
  install needs `boot.loader.grub` instead.
- **A filesystem is missing from the config** — it was not mounted when the
  scan ran. Mount it and re-run `nixos-install-config` (or
  `nixos-generate-config --root /mnt --dir /mnt/etc/nixos/configurations/nixos/<host>`).
