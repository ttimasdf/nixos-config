{
  lib,
  stdenv,
  requireFile,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  qt5,
  gtk3,
  glib,
  zlib,
  libusb1,
  libevdev,
  libinput,
  libpulseaudio,
  libopus,
  libtiff-abi5,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "unicom-cloud-desktop";
  version = "7.11.0-wuying";

  src = requireFile {
    name = "unicom-cloud-desktop-${finalAttrs.version}.deb";
    hash = "sha256-NdqvQVi9jq4YQFRQQQDU6s6rfVNrl9gYS2yJhnUzcxE=";
    message = ''
      Please download the Unicom Cloud Desktop (Wuying) installer and place it in the store:
      $ nix-prefetch-url file:///path/to/unicom-cloud-desktop-${finalAttrs.version}.deb
    '';
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
    qt5.wrapQtAppsHook
  ];

  buildInputs = [
    qt5.qtwebengine
    gtk3
    glib
    libusb1
    zlib
    libevdev
    libinput
    libpulseaudio
    libopus
    libtiff-abi5
  ];

  unpackPhase = ''
    dpkg-deb -x $src .
  '';

  installPhase = ''
    mkdir -p $out/opt $out/bin $out/share
    cp -r opt/wuying $out/opt/
    cp -r usr/share/applications $out/share/
    cp -r usr/share/icons $out/share/

    makeWrapper $out/opt/wuying/bin/wuying $out/bin/wuying \
      --prefix LD_LIBRARY_PATH : "$out/opt/wuying/lib"

    substituteInPlace $out/share/applications/wuying.desktop \
      --replace "Exec=env LD_LIBRARY_PATH=/opt/wuying/lib /opt/wuying/bin/wuying" "Exec=$out/bin/wuying" \
      --replace "Icon=cloudspace-logo" "Icon=$out/share/icons/hicolor/scalable/apps/cloudspace-logo.png"
  '';

  meta = with lib; {
    description = "Wuying Cloud Desktop - Alibaba Cloud productivity tool";
    homepage = "https://www.aliyun.com/product/wuying";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
})
