# spd5118-module

Patched out-of-tree Linux kernel module for the DDR5 SPD5118 hwmon driver.

This package backports SPD write-protection handling for `drivers/hwmon/spd5118.c`
and builds only the `spd5118.ko` module against the configured NixOS kernel,
instead of rebuilding the entire kernel derivation.

## Problem

On `viscacha`, the Intel i801 SMBus controller reports:

```text
i801_smbus 0000:00:1f.4: SPD Write Disable is set
```

This means writes to SPD EEPROM / hub-controller addresses, typically
`0x50` through `0x57`, are blocked by the platform firmware or controller
configuration. The DDR5 SPD5118 hub is still readable, but writes fail.

The upstream `spd5118` hwmon driver historically exposed several writable
sysfs attributes and also performed register writes during suspend/resume via
regmap cache handling. With SPD write protection enabled, those writes can fail
with `-ENXIO` and produce resume errors.

A real failure from `viscacha` before this patched module was installed:

```text
2026-07-11T14:58:20+08:00 viscacha kernel: i801_smbus 0000:00:1f.4: SPD Write Disable is set
2026-07-11T14:58:20+08:00 viscacha kernel: spd5118 0-0050: DDR5 temperature sensor: vendor 0x00:0xb3 revision 2.2
2026-07-11T14:59:26+08:00 viscacha kernel: spd5118 0-0050: Failed to write b = 0: -6
2026-07-11T14:59:26+08:00 viscacha kernel: spd5118 0-0050: PM: dpm_run_callback(): spd5118_resume [spd5118] returns -6
2026-07-11T14:59:26+08:00 viscacha kernel: spd5118 0-0050: PM: failed to resume async: error -6
```

The previous local workaround was to blacklist `spd5118`. That avoided the
resume failure, but it also disabled DDR5 DIMM temperature reporting.

## Related reports

This failure is not unique to `viscacha`. Public reports describe the same
SPD5118 suspend/resume class on multiple DDR5 laptops and distributions:

- [Bug 219721 - spd5118 11-0050: Failed to write b = 0: -6](https://bugzilla.kernel.org/show_bug.cgi?id=219721)
- [Suspend/resume failing due to SPD5118](https://lore.kernel.org/lkml/92a841f0-ab20-4243-9d95-54205790d616@roeck-us.net/T/)
- [SPD5118 resume error (-6) on suspend (Linux, BIOS write protection issue)](https://www.dell.com/community/en/conversations/inspiron/spd5118-resume-error-6-on-suspend-linux-bios-write-protection-issue/69087437b29b5468b84cae7b)
- [Qubes OS issue #9720](https://github.com/QubesOS/qubes-issues/issues/9720)

Kernel Bugzilla 219721 is filed under `Power Management / Other`, hardware
`Intel Linux`, status `NEW`; it was reported on 2025-01-25 and last modified on
2026-06-30. The reports show repeated `spd5118_resume` failures like:

```text
spd5118 11-0050: Failed to write b = 0: -6
spd5118 11-0050: PM: dpm_run_callback(): spd5118_resume [spd5118] returns -6
spd5118 11-0050: PM: failed to resume async: error -6
```

The symptoms range from noisy resume logs to incomplete DDR5 temperature sensor
readings, failed suspend/hibernate attempts, and occasional resume freezes. The
common workaround is to blacklist `spd5118`, but that removes DIMM temperature
monitoring entirely.

The kernel mailing-list thread started with `spd5118` resume timeouts (`-110`)
seen in Intel `xe`/`i915` CI. Guenter Roeck noted that the resume path tries to
write data back to the SPD5118 chip and that the observed timeout originates
from the I2C controller path. Later messages connected another failure case to
`i801_smbus ... SPD Write Disable is set`; Guenter described that state as
incompatible with SPD5118 devices and linked the i2c-side proposal to avoid
instantiating `spd5118` when Intel `i801` reports SPD write disable:

- [i2c: i801: Do not instantiate SPD5118 hub when writing is disabled](https://lore.kernel.org/linux-i2c/20250430-for-upstream-i801-spd5118-no-instantiate-v2-0-2f54d91ae2c7@canonical.com/)

The Dell Community report was the useful breadcrumb for the working fix. It
adds vendor-forum evidence from an Inspiron 14 Plus 7420 on firmware `1.32.0`,
running Arch Linux kernels `6.17.6` and `6.12.56 LTS`, and frames the issue as
BIOS/EC-level SPD5118 EEPROM write protection: the OS only needs read access for
monitoring, but the firmware write-protection state prevents the Linux driver's
write/synchronization path from completing. The thread points at the same
upstream context that led to the Patchew hwmon patch series used here.

The local `viscacha` failure matches that SPD write-protection variant: Intel
`i801` reports `SPD Write Disable is set`, `spd5118` binds on the I801 adapter,
and resume writes fail with `-ENXIO` (`-6`). Applying the Patchew hwmon fix as
an out-of-tree module resolved the local suspend/resume failure while keeping
DDR5 DIMM temperature monitoring available. This package intentionally backports
that hwmon-side behavior instead of using the i2c-side non-instantiation
proposal: the patched `spd5118` driver tolerates write-protected devices by
exposing write-capable attributes as read-only and skipping write paths that
would fail.

## Fix

This package applies the upstream Patchew patch series that fixed `viscacha`:

- [hwmon: spd5118: SPD write-protection detection](https://patchew.org/linux/20250416-for-upstream-spd5118-spd-write-prot-detect-v1-0-8b3bcafe9dad@canonical.com/)
- [Patch 1: hwmon: (spd5118) pass spd5118_data to hwmon callbacks](https://patchew.org/linux/20250416-for-upstream-spd5118-spd-write-prot-detect-v1-1-8b3bcafe9dad@canonical.com/)
- [Patch 2: hwmon: (spd5118) restrict writes under SPD write protection](https://patchew.org/linux/20250416-for-upstream-spd5118-spd-write-prot-detect-v1-2-8b3bcafe9dad@canonical.com/)

The backport does the following:

1. Passes `struct spd5118_data` to the hwmon callbacks instead of only the
   regmap pointer, so callbacks can inspect per-device state.
2. Detects at probe time whether writing to `SPD5118_REG_I2C_LEGACY_MODE`
   fails under SPD write protection.
3. Marks write-capable hwmon attributes as read-only when the device is write
   protected.
4. Disables regmap caching for write-protected devices.
5. Skips suspend/resume write paths that would otherwise fail under SPD write
   protection.

The patches are kept as real git-format patches under `patches/` with upstream
authorship, links, signed-off-by lines, and local backport notes.

## Why an out-of-tree module package

The first implementation used `boot.kernelPatches`, which works but forces Nix
to rebuild the entire `linux-zen` kernel whenever the backport changes.

`CONFIG_SENSORS_SPD5118=m` in the current kernel config, so `spd5118` is already
built as a module. That lets us build a replacement `spd5118.ko` against the
stock kernel headers and install it through `boot.extraModulePackages`.

This is much faster for iteration:

- stock kernel can still come from the binary cache;
- only this small module package rebuilds;
- the system module tree is regenerated so `modprobe` sees the replacement.

## How the package works

`default.nix`:

1. Uses `kernel.src` as the source of the in-tree `drivers/hwmon/spd5118.c`.
2. Copies that one driver file into a tiny temporary module build tree.
3. Applies the two backport patches.
4. Writes a small `Makefile` with:

   ```make
   obj-m := spd5118.o
   ```

5. Builds with the configured kernel build directory:

   ```sh
   make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
     M=$PWD/drivers/hwmon \
     modules
   ```

6. Installs the replacement module to:

   ```text
   $out/lib/modules/${kernel.modDirVersion}/updates/drivers/hwmon/spd5118.ko
   ```

7. Installs a depmod override:

   ```text
   override spd5118 * updates
   ```

The `updates/` location plus the depmod override ensures `modprobe spd5118`
selects this patched module instead of the stock in-tree module under
`kernel/drivers/hwmon/`.

## NixOS wiring

`viscacha` wires the module like this:

```nix
boot.extraModulePackages = [
  (pkgs.spd5118-module.override { kernel = config.boot.kernelPackages.kernel; })
];
```

Passing `config.boot.kernelPackages.kernel` is important: the module must be
built against the exact kernel that will boot on the host.

## Validation

Build the standalone module package:

```sh
nix build .#nixosConfigurations.viscacha.pkgs.spd5118-module --print-build-logs
```

Verify the built module:

```sh
find -L result -name 'spd5118.ko*' -print
modinfo $(find -L result -name 'spd5118.ko*' -print -quit)
```

Verify the system module tree prefers the patched module:

```sh
nix build .#nixosConfigurations.viscacha.config.system.modulesTree
modprobe -d "$(readlink -f result)" \
  -S "$(nix eval --raw .#nixosConfigurations.viscacha.config.boot.kernelPackages.kernel.modDirVersion)" \
  --show-depends spd5118
```

Expected result:

```text
insmod .../updates/drivers/hwmon/spd5118.ko
```

After booting the rebuilt system, verify the live system:

```sh
modinfo -n spd5118
modprobe --show-depends spd5118
lsmod | rg '^spd5118\b'
find /sys/bus/i2c/drivers/spd5118 -maxdepth 1 -mindepth 1 -printf '%f -> %l\n'
```

Expected live module path:

```text
/run/booted-system/kernel-modules/lib/modules/<version>/updates/drivers/hwmon/spd5118.ko
```

Check hwmon exposure:

```sh
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$h/name" 2>/dev/null)" = spd5118 ] && echo "$h"
done
```

On `viscacha`, the validated device was:

```text
/sys/class/hwmon/hwmon6 name=spd5118
/sys/bus/i2c/drivers/spd5118/2-0050
```

The write-protection path was active: write-capable attributes were exposed as
read-only (`0444`), for example:

```text
temp1_max    mode=444
temp1_min    mode=444
temp1_crit   mode=444
temp1_lcrit  mode=444
temp1_enable mode=444
```

Suspend/resume validation:

```sh
sudo systemctl suspend
journalctl -k -b --since "10 minutes ago" | \
  rg -i 'spd5118|i801|Failed to write|dpm_run_callback|failed to resume async|PM: failed|SPD Write|SMBus'
```

A good result may still include:

```text
i801_smbus ... SPD Write Disable is set
spd5118 ... DDR5 temperature sensor: vendor ... revision ...
PM: suspend entry (s2idle)
PM: suspend exit
```

But it should not include:

```text
Failed to write ... -6
spd5118_resume ... returns -6
PM: failed to resume async
```

## Caveats

- The loaded module is out-of-tree from the kernel's perspective and taints the
  kernel with `O`. This is expected for a separately built replacement module.
- The package depends on the exact source layout of `drivers/hwmon/spd5118.c` in
  the configured kernel. If the kernel source changes enough that the patches no
  longer apply, update or drop this package.
- Once the equivalent fix lands in the configured kernel, remove this package and
  the `boot.extraModulePackages` entry so the stock in-tree module is used again.
