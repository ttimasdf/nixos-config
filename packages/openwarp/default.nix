{
  fetchurl,
  stdenv,
  autoPatchelfHook,
  makeWrapper,
  lib,
  makeDesktopItem,
  copyDesktopItems,
  dpkg,
  # Runtime dependencies
  alsa-lib,
  dbus,
  fontconfig,
  libdrm,
  libglvnd,
  libxcb,
  libxkbcommon,
  libpulseaudio,
  mesa,
  udev,
  wayland,
  xz,
  zlib,
  libX11,
  libXcursor,
  libXi,
}:

let
  pname = "openwarp";
  version = "2026.05.08.preview";

  src = fetchurl {
    url = "https://github.com/zerx-lab/warp/releases/download/v${version}/warp-terminal-oss_${version}_amd64.deb";
    hash = "sha256-7FSiKewjhS2e41WNzJF8DHA0C6U4Kc+9nWMSyYmn4P0=";
  };

  libraries = [
    alsa-lib
    dbus
    fontconfig
    libdrm
    libglvnd
    libxcb
    libxkbcommon
    libpulseaudio
    mesa
    udev
    wayland
    xz
    zlib
    libX11
    libXcursor
    libXi
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
    buildInputs = libraries;

    unpackPhase = ''
      runHook preUnpack
      dpkg -x $src .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/opt/warpdotdev $out/bin

      # Copy the application files
      cp -r opt/warpdotdev/warp-terminal-oss $out/opt/warpdotdev/

      # Entrypoint wrapper
      makeWrapper $out/opt/warpdotdev/warp-terminal-oss/warp-oss $out/bin/warp-oss \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath libraries}" \
        --chdir "$out/opt/warpdotdev/warp-terminal-oss"

      runHook postInstall
    '';

    # Copy icons from the deb
    preFixup = ''
      mkdir -p $out/share/icons
      cp -r usr/share/icons/hicolor $out/share/icons/
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "dev.warp.OpenWarp";
        desktopName = "OpenWarp";
        genericName = "TerminalEmulator";
        exec = "warp-oss %U";
        icon = "dev.warp.OpenWarp";
        comment = "Warp Terminal - OSS Edition";
        categories = [ "System" "TerminalEmulator" ];
        keywords = [ "shell" "prompt" "command" "commandline" "cmd" ];
        mimeTypes = [ "x-scheme-handler/openwarp" ];
        startupWMClass = "dev.warp.OpenWarp";
      })
    ];

    meta = with lib; {
      description = "Warp is a modern, Rust-based terminal with AI built in so you and your team can build great software, faster";
      homepage = "https://github.com/zerx-lab/warp";
      license = licenses.unfree; # OSS edition but with proprietary bits
      platforms = [ "x86_64-linux" ];
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
      mainProgram = "warp-oss";
    };
  })
