{
  lib,
  stdenv,
  requireFile,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  makeWrapper,
  qt6,
  python3,
  curl,
  cairo,
  dbus,
  fontconfig,
  freetype,
  glib,
  gtk3,
  libdrm,
  libGL,
  libkrb5,
  libsecret,
  libunwind,
  libxkbcommon,
  openssl,
  xorg,
  zlib,
}:
let
  pname = "ida-pro";
  version = "9.2.0.250908";

  src = requireFile {
    name = with lib.versions; "ida-pro_${major version}${minor version}_x64linux.run";
    hash = "sha256-qt0PiulyuE+U8ql0g0q/FhnzvZM7O02CdfnFAAjQWuE=";
    message = ''
      Please download the IDA Pro installer and place it in the store:
      $ nix-prefetch-url file:///path/to/idapro-${version}.run
    '';
  };

  pythonEnv = python3.withPackages (p: with p; [ rpyc ]);

in
stdenv.mkDerivation rec {
  inherit pname version;

  inherit src;

  desktopItem = makeDesktopItem {
    name = "ida-pro";
    exec = "ida";
    icon = ./ida.png;
    comment = meta.description;
    desktopName = "IDA Pro ${lib.versions.majorMinor version}";
    genericName = "Interactive Disassembler";
    categories = [ "Development" ];
    startupWMClass = "IDA";
  };
  desktopItems = [ desktopItem ];

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
    autoPatchelfHook
    qt6.wrapQtAppsHook
  ];

  # We just get a runfile in $src, so no need to unpack it.
  dontUnpack = true;

  # Add everything to the RPATH, in case IDA decides to dlopen things.
  runtimeDependencies = [
    cairo
    dbus
    fontconfig
    freetype
    glib
    gtk3
    libdrm
    libGL
    libkrb5
    libsecret
    qt6.qtbase
    qt6.qtwayland
    libunwind
    libxkbcommon
    libsecret
    openssl
    stdenv.cc.cc
    xorg.libICE
    xorg.libSM
    xorg.libX11
    xorg.libXau
    xorg.libxcb
    xorg.libXext
    xorg.libXi
    xorg.libXrender
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    xorg.xcbutilwm
    zlib
    curl
    pythonEnv
  ];
  buildInputs = runtimeDependencies;

  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    function print_debug_info() {
      if [ -f installbuilder_installer.log ]; then
        cat installbuilder_installer.log
      else
        echo "No debug information available."
      fi
    }

    trap print_debug_info EXIT

    mkdir -p $out/bin $out/lib $out/opt/idapro/.local/share/applications

    # IDA depends on quite some things extracted by the runfile, so first extract everything
    # into $out/opt, then remove the unnecessary files and directories.
    IDADIR="$out/opt/idapro"
    # IDA doesn't always honor `--prefix`, so we need to hack and set $HOME here.
    HOME="$out/opt/idapro"

    # Invoke the installer with the dynamic linker (ld-linux-x86-64.so.2) directly, 
    # avoiding the need to copy it to fix permissions and patch the executable.
    $(cat $NIX_CC/nix-support/dynamic-linker) "$src" \
      --mode unattended --debuglevel 4 --prefix $IDADIR

    # Link the exported libraries to the output.
    for lib in $IDADIR/*.so $IDADIR/*.so.6; do
      ln -s $lib $out/lib/$(basename $lib)
    done

    # Manually patch libraries that dlopen stuff.
    patchelf \
      --add-needed libpython${lib.versions.majorMinor python3.version}.so \
      --add-needed libcrypto.so \
      --add-needed libsecret-1.so.0 \
      "$out/lib/libida.so"

    # Some libraries come with the installer.
    addAutoPatchelfSearchPath $IDADIR

    # Link the binaries to the output.
    # Also, hack the PATH so that pythonEnv is used over the system python.
    for bin in ida; do
      makeWrapper "$IDADIR/$bin" "$out/bin/$bin" \
        --prefix IDADIR : $IDADIR \
        --prefix QT_PLUGIN_PATH : $IDADIR/plugins/platforms \
        --prefix PYTHONPATH : $out/bin/idalib/python \
        --prefix PATH : ${pythonEnv}/bin:$IDADIR \
        --prefix LD_LIBRARY_PATH : $out/lib
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "The world's smartest and most feature-full disassembler";
    homepage = "https://hex-rays.com/ida-pro/";
    license = licenses.unfree;
    mainProgram = "ida";
    maintainers = with maintainers; [ msanft ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };

  passthru = {
    updateScript = [
      "#!/usr/bin/env nix-shell"
      "#!nix-shell -i bash -p nix-update"
      "nix-update idapro --version-regex 'idapro-(.*).run' --version $1"
    ];
  };
}