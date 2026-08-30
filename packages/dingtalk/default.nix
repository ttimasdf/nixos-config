{
  fetchurl,
  stdenv,
  callPackage,
  autoPatchelfHook,
  makeWrapper,
  lib,
  makeDesktopItem,
  copyDesktopItems,
  dpkg,
  # DingTalk dependencies
  wrapGAppsHook3,
  alsa-lib,
  apr,
  aprutil,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  curl,
  dbus,
  e2fsprogs,
  fontconfig,
  freetype,
  fribidi,
  gdk-pixbuf,
  glib,
  gnome2,
  gnutls,
  graphite2,
  gtk3,
  harfbuzz,
  icu63,
  krb5,
  libdrm,
  libgcrypt,
  libGLU,
  libglvnd,
  libidn2,
  libinput,
  libjpeg,
  libpng,
  libpsl,
  libpulseaudio,
  libssh2,
  libthai,
  libxcrypt-legacy,
  libxkbcommon,
  mesa,
  mtdev,
  nghttp2,
  nspr,
  nss,
  opencv,
  openldap,
  openssl,
  pango,
  pcre2,
  pipewire,
  prelink,
  qt5,
  rtmpdump,
  udev,
  util-linux,
  libICE,
  libSM,
  libX11,
  libxcb,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXinerama,
  libXmu,
  libXrandr,
  libXrender,
  libXScrnSaver,
  libXt,
  libXtst,
  xcbutilimage,
  xcbutilkeysyms,
  xcbutilrenderutil,
  xcbutilwm,
}:
################################################################################
# Mostly based on dingtalk-bin package from AUR:
# https://aur.archlinux.org/packages/dingtalk-bin
################################################################################
let
  pname = "dingtalk";
  version = "8.1.0.6021101";

  src = fetchurl {
    url = "https://dtapp-pub.dingtalk.com/dingtalk-desktop/xc_dingtalk_update/linux_deb/Release/com.alibabainc.dingtalk_${version}_amd64.deb";
    hash = "sha256-7EkvEv6r7ONHAupH48/BoWSuLo2r3umwXnSjpeTeIdU=";
  };

  dingtalk-wayland-screenshare = callPackage ./wayland-screenshare.nix {};

  libraries = [
    alsa-lib
    apr
    aprutil
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    curl
    dbus
    e2fsprogs
    fontconfig
    freetype
    fribidi
    gdk-pixbuf
    glib
    gnome2.gtkglext
    gnutls
    graphite2
    gtk3
    harfbuzz
    icu63
    krb5
    libdrm
    libgcrypt
    libGLU
    libglvnd
    libidn2
    libinput
    libjpeg
    libpng
    libpsl
    libpulseaudio
    libssh2
    libthai
    libxcrypt-legacy
    libxkbcommon
    mesa
    mtdev
    nghttp2
    nspr
    nss
    opencv
    openldap
    openssl
    pango
    pcre2
    pipewire
    qt5.qtbase
    qt5.qtmultimedia
    qt5.qtsvg
    qt5.qtx11extras
    rtmpdump
    udev
    util-linux
    libICE
    libSM
    libX11
    libxcb
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXinerama
    libXmu
    libXrandr
    libXrender
    libXScrnSaver
    libXt
    libXtst
    xcbutilimage
    xcbutilkeysyms
    xcbutilrenderutil
    xcbutilwm
  ];
in
  stdenv.mkDerivation (finalAttrs: {
    inherit pname version src;

    nativeBuildInputs = [
      glib
      wrapGAppsHook3
      autoPatchelfHook
      makeWrapper
      prelink
      qt5.wrapQtAppsHook
      copyDesktopItems
      dpkg
    ];
    buildInputs = libraries;

    # We will append QT wrapper args to our own wrapper
    dontWrapQtApps = true;
    dontWrapGApps = true;

    unpackPhase = ''
      runHook preUnpack

      dpkg -x $src .

      mv opt/apps/com.alibabainc.dingtalk/files/version version
      mv opt/apps/com.alibabainc.dingtalk/files/*-Release.* release

      # Cleanup
      rm -f release/{*.a,*.la,*.prl,dingtalk_crash_report,dingtalk_updater,libapr*,libcurl.so.*}
      rm -f release/{libdouble-conversion.so.*,libEGL*,libfontconfig*,libfreetype*,libfribidi*,libgbm.*,libgdk*,libGLES*}
      rm -f release/{libgtk*,libgtk-x11-2.0.so.*,libharfbuzz*,libicu*,libidn2*,libjpeg*,libm.so.*,libnghttp2*}
      rm -f release/{libpango-1.0.*,libpangocairo-1.0.*,libpangoft2-1.0.*,libpcre2*,libpng*,libpsl*,libQt5*,libssh2*}
      rm -f release/{libstdc++.so.6,libstdc++*,libunistring*,libvk*,libvulkan*,libxcb*,libz*}
      # Drop the bundled (old) GLVND libGLX/libGLdispatch. Their RUNPATH does not
      # contain /run/opengl-driver/lib, so GLVND cannot find Mesa's
      # libGLX_mesa.so.0 and every GLX context creation fails with Qt's
      # qFatal("Could not initialize GLX") -> SIGABRT. The NixOS-patched system
      # libglvnd (RUNPATH includes /run/opengl-driver/lib) resolves the vendor
      # library correctly.
      rm -f release/{libGLX*,libGLdispatch*}
      rm -rf release/{imageformats,platform*,swiftshader,xcbglintegrations}
      rm -rf release/Resources/{i18n/tool/*.exe,qss/mac}
      
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      install -Dm644 version $out/version

      # Move libraries
      # DingTalk relies on (some of) the exact libraries it ships with
      mv release $out/lib

      # Entrypoint
      mkdir -p $out/bin
      cat > $out/bin/dingtalk <<EOF
      #!/usr/bin/env bash
      if [[ \''${XMODIFIERS} =~ fcitx ]]; then
        export QT_IM_MODULE=fcitx
        export GTK_IM_MODULE=fcitx
      elif [[ \''${XMODIFIERS} =~ ibus ]]; then
        export QT_IM_MODULE=ibus
        export GTK_IM_MODULE=ibus
        export IBUS_USE_PORTAL=1
      fi

      exec $out/lib/com.alibabainc.dingtalk
      EOF
      chmod +x $out/bin/dingtalk

      # App Menu
      install -Dm644 $out/lib/Resources/image/common/about/logo.png $out/share/pixmaps/dingtalk.png

      runHook postInstall
    '';

    fixupPhase = ''
      runHook preFixup

      # Wrap the binary to set up environment variables and library paths
      #
      # Audio fix: libmeeting_sdk.so dlopen()s "libpulse.so.0" / "libasound.so.2"
      # by bare name, but its RUNPATH only contains $out/lib and libglvnd (and the
      # process has no LD_LIBRARY_PATH), so on NixOS the dlopen fails and the
      # meeting window cannot enumerate any microphone/speaker devices. Put the
      # PulseAudio and ALSA lib dirs on LD_LIBRARY_PATH so the dlopen succeeds.
      #
      # Note: the bundled GLVND libs (libGLX.so.0 / libGLdispatch.so.0) are
      # removed in unpackPhase so the NixOS-patched system libglvnd is used.
      # Otherwise GLX context creation fails ("Could not initialize GLX" ->
      # SIGABRT), because the bundled libGLX has no /run/opengl-driver/lib in its
      # RUNPATH and thus cannot find Mesa's libGLX_mesa.so.0 vendor library.
      wrapProgram $out/bin/dingtalk \
        "''${qtWrapperArgs[@]}" \
        "''${gappsWrapperArgs[@]}" \
        --chdir $out/lib \
        --unset WAYLAND_DISPLAY \
        --set QT_QPA_PLATFORM "xcb" \
        --set QT_AUTO_SCREEN_SCALE_FACTOR 1 \
        --prefix LD_LIBRARY_PATH : "${libpulseaudio}/lib:${alsa-lib}/lib" \
        --prefix LD_PRELOAD : "${dingtalk-wayland-screenshare}/lib/libdingtalkhook.so"

      runHook postFixup
    '';

    postFixup = ''
      execstack -c $out/lib/dingtalk_dll.so
      execstack -c $out/lib/libconference_new.so
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "dingtalk";
        desktopName = "Dingtalk";
        genericName = "dingtalk";
        categories = ["Chat"];
        exec = "dingtalk %u";
        icon = "dingtalk";
        keywords = ["dingtalk"];
        mimeTypes = ["x-scheme-handler/dingtalk"];
        extraConfig = {
          "Name[zh_CN]" = "钉钉";
          "Name[zh_TW]" = "釘釘";
        };
      })
    ];

    passthru = {inherit dingtalk-wayland-screenshare;};

    meta = {
      maintainers = with lib.maintainers; [xddxdd];
      description = "Enterprise communication and collaboration platform developed by Alibaba Group";
      homepage = "https://www.dingtalk.com/";
      platforms = ["x86_64-linux"];
      license = lib.licenses.unfreeRedistributable;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      mainProgram = "dingtalk";
    };
  })
