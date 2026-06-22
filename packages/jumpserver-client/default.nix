{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, dpkg
, wrapGAppsHook3
, cairo
, dbus
, fontconfig
, gdk-pixbuf
, glib
, glib-networking
, gtk3
, libayatana-appindicator
, libsoup_3
, openssl
, webkitgtk_4_1
, xdg-utils
, libX11
, libXi
}:

let
  runtimeDependencies = [
    cairo
    dbus
    fontconfig
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    libayatana-appindicator
    libsoup_3
    openssl
    stdenv.cc.cc.lib
    webkitgtk_4_1
    xdg-utils
    libX11
    libXi
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "jumpserver-client";
  version = "4.1.2";

  src = fetchurl {
    url = "https://github.com/jumpserver/client/releases/download/v${finalAttrs.version}/JumpServerClient_${finalAttrs.version}_amd64.deb";
    hash = "sha256-571BER65081Z5G/VH43WOmrTNvjIoVORxvSWA2ofFns=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    wrapGAppsHook3
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

    install -Dm755 usr/bin/JumpServerClient $out/bin/JumpServerClient
    ln -s JumpServerClient $out/bin/jumpserver-client

    mkdir -p $out/lib $out/share/applications $out/share/icons
    cp -r usr/lib/JumpServerClient $out/lib/
    cp -r usr/share/icons/hicolor $out/share/icons/
    cp usr/share/applications/JumpServerClient.desktop $out/share/applications/

    substituteInPlace $out/share/applications/JumpServerClient.desktop \
      --replace-fail "Exec=JumpServerClient" "Exec=jumpserver-client %U" \
      --replace-fail "MimeType=x-scheme-handler/jms" "MimeType=x-scheme-handler/jms;"

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeDependencies}"
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
    )
  '';

  meta = {
    description = "JumpServer desktop client for launching remote sessions";
    homepage = "https://github.com/jumpserver/client";
    downloadPage = "https://github.com/jumpserver/client/releases";
    license = lib.licenses.gpl3Only;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "jumpserver-client";
  };
})
