# Keep USB storage from hoarding dirty page cache, so that unmounting or
# ejecting a stick never has to flush gigabytes of buffered writes first.
#
# The kernel's global limits (vm.dirty_ratio / vm.dirty_bytes) allow several
# GiB of dirty pages. A multi-GB copy to a slow stick stays well below
# vm.dirty_background_ratio, so background write-back never even starts: `cp`
# returns with the data still in RAM, and the flush then happens during
# unmount, which blocks for as long as the transfer takes.
#
# Lowering the global limits would fix that too, but it throttles every other
# writer on the machine (including fast internal NVMe) and lets one slow device
# consume the shared dirty budget. Capping the backing device (BDI) instead
# keeps the change local to USB storage:
#
#   max_bytes    max dirty pages attributed to this device
#   strict_limit enforce that cap even while the global limit is not exceeded
#                (mm/page-writeback.c: wb_dirty_exceeded() only needs the
#                global threshold when the BDI is not strict-limit capable)
#
# See https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-bdi
#
# Known limitation: writes through a device-mapper layer (e.g. a LUKS-encrypted
# USB drive) are accounted to the dm device's BDI, not the USB disk's, so this
# rule does not bound them.
{ pkgs, lib, config, ... }:
let
  capBytes = config.rabit.nixos.usbWritebackCapBytes;

  # Runs from udev, whose PATH does not contain NixOS' coreutils; stick to
  # shell builtins. $1 is the kernel name of the added block device (%k).
  capWriteback = pkgs.writeShellScript "cap-usb-writeback" ''
    set -eu
    [ -r "/sys/block/$1/dev" ] || exit 0
    bdi="/sys/class/bdi/$(< "/sys/block/$1/dev")"
    [ -d "$bdi" ] || exit 0
    printf '%s\n' ${toString capBytes} > "$bdi/max_bytes"
    printf '1\n' > "$bdi/strict_limit"
  '';
in
{
  options.rabit.nixos.usbWritebackCapBytes = lib.mkOption {
    type = lib.types.nullOr lib.types.ints.positive;
    default = 16 * 1024 * 1024;
    example = 64 * 1024 * 1024;
    description = ''
      Maximum amount of dirty page cache, in bytes, that a USB block device may
      hold before writers are throttled. Applied per backing device through
      sysfs `max_bytes` and `strict_limit`, so it is enforced regardless of how
      high the global `vm.dirty_*` limits are and without affecting other
      drives.

      This bounds how much remains to be flushed at unmount time, making
      `udisksctl unmount`/eject return immediately after a copy finishes instead
      of blocking on a full device-buffer flush. The cost is that the copy
      itself is paced by the device instead of finishing early into page cache;
      total wall clock is unchanged.

      Set to `null` to leave the kernel defaults (`vm.dirty_ratio` only) in
      place for USB devices.
    '';
  };

  # udev is what applies the cap, so there is nothing to do where it is off
  # (e.g. WSL, which has no block devices to yank).
  config = lib.mkIf (capBytes != null && config.services.udev.enable) {
    # SUBSYSTEMS=="usb" matches any block device behind a USB parent: plain
    # sticks, USB-SATA bridges and card readers. ENV{DEVTYPE}=="disk" keeps the
    # rule off partitions (they share the whole disk's BDI).
    # Check the match with `udevadm info -a -n /dev/sdX`.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", SUBSYSTEMS=="usb", RUN+="${capWriteback} %k"
    '';
  };
}
