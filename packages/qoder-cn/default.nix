{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  dpkg,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  bubblewrap,
  cairo,
  cups,
  curl,
  dbus,
  expat,
  fontconfig,
  gtk3,
  libdrm,
  libgbm,
  libsecret,
  libxkbcommon,
  libxkbfile,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  vulkan-loader,
  xdg-utils,
  zlib,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxcb,
}:

let
  pname = "qoder-cn";
  version = "1.8.0";

  src = fetchurl {
    url = "https://ide.qoder.com.cn/qoder/release/${version}/qoder-cn_amd64.deb";
    hash = "sha256-Rw/e8nx7IfgxXnn3ZIoDgbn8czZ/4CcquedjxVWoBC0=";
  };

  runtimeDependencies = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    bubblewrap
    cairo
    cups
    curl
    dbus
    expat
    fontconfig
    gtk3
    libdrm
    libgbm
    libsecret
    libxkbcommon
    libxkbfile
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
    vulkan-loader
    xdg-utils
    zlib
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxcb
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

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile $src | tar --extract --no-same-owner --no-same-permissions
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/applications $out/share/pixmaps

    cp -r usr/share/qoder-cn $out/share/
    chmod 0755 $out/share/qoder-cn/chrome-sandbox
    cp usr/share/applications/*.desktop $out/share/applications/
    cp usr/share/pixmaps/QoderCN.png $out/share/pixmaps/

    substituteInPlace $out/share/applications/qoder-cn.desktop \
      --replace-fail /usr/share/qoder-cn/qoder-cn $out/bin/qoder-cn

    substituteInPlace $out/share/applications/qoder-cn-url-handler.desktop \
      --replace-fail /usr/share/qoder-cn/qoder-cn $out/bin/qoder-cn

    makeWrapper $out/share/qoder-cn/bin/qoder-cn $out/bin/qoder-cn \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeDependencies} \
      --add-flags --no-sandbox

    makeWrapper $out/share/qoder-cn/bin/qoder-cn-tunnel $out/bin/qoder-cn-tunnel \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeDependencies}

    makeWrapper $out/share/qoder-cn/resources/app/resources/bin/x86_64_linux/QoderCN $out/bin/qoder-cn-cli

    runHook postInstall
  '';

  meta = {
    description = "Agentic coding platform designed for real software development";
    homepage = "https://qoder.cn";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "qoder-cn";
  };
})
