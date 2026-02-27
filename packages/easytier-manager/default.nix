{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,

  cargo-tauri,
  fetchPnpmDeps,
  pnpmConfigHook,
  wrapGAppsHook4,
  copyDesktopItems,
  makeDesktopItem,
  nodejs,
  pnpm,
  pkg-config,

  openssl,
  webkitgtk_4_1,
  libsoup_3,
  glib-networking,
  libayatana-appindicator,
  easytier,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "easytier-manager";
  version = "3.2.7";

  src = fetchFromGitHub {
    owner = "ttimasdf";
    repo = "easytier-manager";
    rev = "ce725381b8ebae135a5e46d31a3afe0e05d3ad38";
    hash = "sha256-svAWO9hYK9/C/i5a5ryGYatwX+IDnnI6/Jt1Fs9XHfs=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoHash = "sha256-7LsQpDg4uAkeJbPtuvkAHfch26BJj5dXQrXhjD78AGI=";

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-GNKdTE9+eeqP6ihQD6JsQtmbrGpyv2RLe548jvZDMQI=";
    fetcherVersion = 3;
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    rustPlatform.cargoCheckHook
    rustPlatform.cargoSetupHook
    nodejs
    pnpm
    pnpmConfigHook
    wrapGAppsHook4
    copyDesktopItems
  ] ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
    pkg-config
  ];

  buildInputs = [
    libayatana-appindicator
    webkitgtk_4_1
    libsoup_3
    glib-networking
  ] ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
    openssl
  ];

  env.OPENSSL_NO_VENDOR = true;

  postPatch = ''
    substituteInPlace $cargoDepsCopy/libappindicator-sys-*/src/lib.rs \
      --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "easytier-manager";
      exec = "easytier-manager-pro";
      icon = "easytier-manager";
      desktopName = "EasyTier Manager Pro";
      comment = "EasyTier Manager Pro - A visual desktop application for EasyTier";
      categories = [ "Network" "Utility" ];
      terminal = false;
    })
  ];

  meta = with lib; {
    description = "EasyTier Manager Pro - A visual desktop application for EasyTier";
    longDescription = ''
      EasyTier Manager Pro is a visual desktop application designed for the EasyTier kernel.
      It supports starting/stopping networking with one click through the interface,
      modifying kernel parameters, viewing real-time logs, and downloading any version
      of the kernel with one click.
    '';
    homepage = "https://github.com/EasyTier/easytier-manager";
    license = licenses.agpl3Only;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "easytier-manager-pro";
  };
})
