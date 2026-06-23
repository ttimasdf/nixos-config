{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, makeDesktopItem
, copyDesktopItems
, dpkg
, # Runtime dependencies
  alsa-lib
, dbus
, fontconfig
, libdrm
, libglvnd
, libxcb
, libxkbcommon
, vulkan-loader
, wayland
, xdg-utils
, xz
, zlib
, libX11
, libXcursor
, libXi
, # Options
  waylandSupport ? false
,
}:

let
  pname = "zap";
  version = "2026.06.21.1";

  src = fetchurl {
    url = "https://github.com/zerx-lab/zap/releases/download/v${version}/zap_${version}_amd64.deb";
    hash = "sha256-l5MfkP0KvkOXiwxhmZHGfnf2wKh0qxHodyC3Fowinrg=";
  };

  runtimeDependencies = [
    alsa-lib
    dbus
    fontconfig
    libdrm
    libglvnd
    libxcb
    libxkbcommon
    (lib.getLib stdenv.cc.cc)
    stdenv.cc.libc
    vulkan-loader
    xdg-utils
    xz
    zlib

    # X11 support
    libX11
    libXcursor
    libXi
  ] ++ lib.optionals waylandSupport [
    wayland
  ];
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version src;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
    dpkg
  ];

  buildInputs = runtimeDependencies;

  # Force-link libfontconfig so Zap can discover system fonts.
  # https://github.com/warpdotdev/Warp/issues/5793
  patchelfFlags = lib.concatMap (lib: [ "--add-needed" lib ]) [
    "libfontconfig.so.1"
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile $src | tar --extract --no-same-owner --no-same-permissions
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin $out/share/icons

    cp -r opt/zap $out/opt/
    cp -r usr/share/icons/hicolor $out/share/icons/

    makeWrapper $out/opt/zap/zap-oss $out/bin/zap \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeDependencies} \
      ${lib.optionalString waylandSupport "--set WARP_ENABLE_WAYLAND 1"}

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "dev.zap.Zap";
      desktopName = "Zap";
      genericName = "TerminalEmulator";
      exec = "zap %U";
      icon = "dev.zap.Zap";
      comment = "Zap, a community fork of the Rust-based Warp terminal";
      categories = [ "System" "TerminalEmulator" ];
      keywords = [ "shell" "prompt" "command" "commandline" "cmd" ];
      mimeTypes = [ "x-scheme-handler/zap" ];
      startupWMClass = "dev.zap.Zap";
    })
    (makeDesktopItem {
      name = "dev.zap.Zap.NewTab";
      desktopName = "Zap File Handler";
      exec = "zap \"zap://action/new_tab?path=%f\"";
      icon = "dev.zap.Zap";
      comment = "Open a new Zap tab in the specified directory";
      categories = [ "System" "TerminalEmulator" ];
      noDisplay = true;
      mimeTypes = [ "inode/directory" ];
      startupWMClass = "dev.zap.Zap";
    })
  ];

  meta = {
    description = "Community fork of the Rust-based Warp terminal";
    homepage = "https://github.com/zerx-lab/zap";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "zap";
  };
})
