{
  fetchurl,
  stdenv,
  autoPatchelfHook,
  makeBinaryWrapper,
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
  vulkan-loader,
  wayland,
  xdg-utils,
  xz,
  zlib,
  libX11,
  libXcursor,
  libXi,
  # Options
  waylandSupport ? false,
}:

let
  pname = "openwarp";
  version = "0.2026.05.13.1008";

  src = fetchurl {
    url = "https://github.com/zerx-lab/warp/releases/download/v${version}/warp-terminal-oss_${version}_amd64.deb";
    hash = "sha256-Gqeg+vKYUvtm+h8LP9nGJHqnHfj4O3krRYSkWGVVAG0=";
  };
in
  stdenv.mkDerivation (finalAttrs: {
    inherit pname version src;

    nativeBuildInputs = [
      autoPatchelfHook
      makeBinaryWrapper
      copyDesktopItems
      dpkg
    ];

    buildInputs = [
      alsa-lib
      dbus
      fontconfig
      (lib.getLib stdenv.cc.cc)
      xz
      zlib
    ];

    runtimeDependencies = [
      fontconfig.lib
      stdenv.cc.libc
      libdrm
      libglvnd
      libxcb
      libxkbcommon
      vulkan-loader
      xdg-utils

      ## X11 support
      libX11
      libXcursor
      libXi
    ] ++ lib.optionals waylandSupport [
      wayland
    ];

    # Force-link libfontconfig so Warp can discover system fonts
    # https://github.com/warpdotdev/Warp/issues/5793
    patchelfFlags = lib.concatMap (lib: [ "--add-needed" lib ]) [
      "libfontconfig.so.1"
    ];

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

      # Copy icons from the deb
      mkdir -p $out/share/icons
      cp -r usr/share/icons/hicolor $out/share/icons/

      # Rename icons to match the actual app_id (openwarp, not warp)
      for dir in $out/share/icons/hicolor/*/apps; do
        for f in "$dir"/dev.warp.OpenWarp.png; do
          # if this step fails in future version, we'll remove this workaround completely
          mv "$f" "$dir/dev.openwarp.OpenWarp.png"
        done
      done

      # Wrapper with WARP_ENABLE_WAYLAND for native Wayland support
      makeWrapper $out/opt/warpdotdev/warp-terminal-oss/warp-oss $out/bin/warp-oss \
        ${lib.optionalString waylandSupport "--set WARP_ENABLE_WAYLAND 1"}

      runHook postInstall
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "dev.openwarp.OpenWarp";
        desktopName = "OpenWarp";
        genericName = "TerminalEmulator";
        exec = "warp-oss %U";
        icon = "dev.openwarp.OpenWarp";
        comment = "Warp Terminal - OSS Edition";
        categories = [ "System" "TerminalEmulator" ];
        keywords = [ "shell" "prompt" "command" "commandline" "cmd" ];
        mimeTypes = [ "x-scheme-handler/openwarp" ];
        startupWMClass = "dev.openwarp.OpenWarp";
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
