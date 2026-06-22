{ lib
, stdenv
, requireFile
, autoPatchelfHook
, makeWrapper
, dpkg
, alsa-lib
, at-spi2-atk
, at-spi2-core
, cairo
, cups
, dbus
, expat
, fontconfig
, gdk-pixbuf
, glib
, gtk3
, libayatana-appindicator
, libdrm
, libgbm
, libnotify
, libsecret
, libuuid
, libxkbcommon
, nspr
, nss
, pango
, systemd
, xdg-utils
, zlib
, libX11
, libxcb
, libXcomposite
, libXdamage
, libXext
, libXfixes
, libXrandr
, libXScrnSaver
, libXtst
,
}:

let
  runtimeDependencies = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    gdk-pixbuf
    glib
    gtk3
    libayatana-appindicator
    libdrm
    libgbm
    libnotify
    libsecret
    libuuid
    libxkbcommon
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
    xdg-utils
    zlib
    libX11
    libxcb
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libXScrnSaver
    libXtst
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "jumpserver-client";
  version = "3.0.4";

  src = requireFile {
    name = "JumpServer-Client-Installer-linux-v${finalAttrs.version}-amd64.deb";
    hash = "sha256-ko9rJesL3RPL3O2SYQwELl7yUg8DBN+wdgBPd627Qi0=";
    message = ''
      This package uses the locally downloaded JumpServer Client .deb.

      Add it to the Nix store with:
        nix-store --add-fixed sha256 source/JumpServer-Client-Installer-linux-v${finalAttrs.version}-amd64.deb
    '';
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    dpkg
  ];

  buildInputs = runtimeDependencies;

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack

    dpkg-deb --fsys-tarfile $src | tar --extract --no-same-owner --no-same-permissions

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/opt $out/share/applications $out/share/icons

    cp -r opt/JumpServerClient $out/opt/
    cp -r usr/share/icons/hicolor $out/share/icons/
    cp usr/share/applications/jumpserver-client.desktop $out/share/applications/

    chmod 0755 $out/opt/JumpServerClient/chrome-sandbox

    substituteInPlace $out/share/applications/jumpserver-client.desktop \
      --replace-fail "Exec=/opt/JumpServerClient/jumpserver-client %U" "Exec=jumpserver-client %U"

    makeWrapper $out/opt/JumpServerClient/jumpserver-client $out/bin/jumpserver-client \
      --chdir $out/opt/JumpServerClient \
      --prefix LD_LIBRARY_PATH : "$out/opt/JumpServerClient:${lib.makeLibraryPath runtimeDependencies}" \
      --add-flags "--no-sandbox"

    runHook postInstall
  '';

  meta = {
    description = "JumpServer desktop client for launching remote sessions";
    homepage = "https://github.com/jumpserver/client";
    downloadPage = "https://github.com/jumpserver/client/releases";
    license = lib.licenses.unfreeRedistributable;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "jumpserver-client";
  };
})
