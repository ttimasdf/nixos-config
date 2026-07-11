{
  lib,
  stdenv,
  kernel ? linuxPackages_zen.kernel,
  linuxPackages_zen,
  kmod,
  xz,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "spd5118-module";
  version = "${kernel.version}-2025-04-16";

  src = kernel.src;
  dontUnpack = true;

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [
    kmod
    xz
  ];

  buildPhase = ''
    runHook preBuild

    mkdir -p drivers/hwmon
    cp ${kernel.src}/drivers/hwmon/spd5118.c drivers/hwmon/spd5118.c
    chmod u+w drivers/hwmon/spd5118.c

    patch -p1 < ${./patches/0001-hwmon-spd5118-pass-spd5118_data-to-hwmon-callbacks.patch}
    patch -p1 < ${./patches/0002-hwmon-spd5118-restrict-writes-under-SPD-write-protection.patch}

    cat > drivers/hwmon/Makefile <<'MAKEFILE'
    obj-m := spd5118.o
    MAKEFILE

    make \
      -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      M=$PWD/drivers/hwmon \
      modules

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm444 \
      drivers/hwmon/spd5118.ko \
      $out/lib/modules/${kernel.modDirVersion}/updates/drivers/hwmon/spd5118.ko

    install -Dm444 /dev/stdin $out/etc/depmod.d/spd5118.conf <<'DEPMOD'
    override spd5118 * updates
    DEPMOD

    runHook postInstall
  '';

  meta = {
    description = "Patched SPD5118 hwmon kernel module with SPD write-protection handling";
    homepage = "https://patchew.org/linux/20250416-for-upstream-spd5118-spd-write-prot-detect-v1-0-8b3bcafe9dad@canonical.com/";
    license = lib.licenses.gpl2Plus;
    maintainers = [ ];
    platforms = lib.platforms.linux;
    broken = lib.versionOlder kernel.version "6.11";
  };
})
