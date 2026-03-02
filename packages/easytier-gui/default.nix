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
  protobuf,

  openssl,
  webkitgtk_4_1,
  libsoup_3,
  glib-networking,
  libayatana-appindicator,
  easytier,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "easytier-gui";
  version = "2.5.0";

  src = fetchFromGitHub {
    owner = "EasyTier";
    repo = "EasyTier";
    rev = "v${finalAttrs.version}";
    hash = "sha256-XnEfxWDKUTQFWYKtqetI7sLbOmGqw2BqpU5by1ajZGA=";
  };

  cargoHash = "sha256-ueDulcv7DnwvMWYayc3hzBVtldX6gg7fP7YQpdUPq7c=";

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-+moKz50dIGkgSi6lASWf1vzlAjAlA9IH5Pa3PbWKOas=";
    fetcherVersion = 3;
  };

  # The Tauri project is in easytier-gui subdirectory
  # but needs access to the workspace root for Cargo.lock
  tauriFrontendDist = "easytier-gui/dist";
  tauriCargoManifest = "easytier-gui/src-tauri/Cargo.toml";

  # Build workspace dependencies first
  preBuild = ''
    # Build all workspace packages (including easytier-frontend-lib)
    pnpm -r build
  '';

  # Skip tests - they include network tests that timeout in sandbox
  doCheck = false;

  nativeBuildInputs = [
    pnpmConfigHook
    rustPlatform.bindgenHook
    cargo-tauri.hook
    wrapGAppsHook4
    copyDesktopItems
    nodejs
    pnpm
    protobuf
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
      name = "easytier-gui";
      exec = "easytier-gui";
      icon = "easytier-gui";
      desktopName = "EasyTier GUI";
      comment = "EasyTier GUI - A visual desktop application for EasyTier";
      categories = [ "Network" "Utility" ];
      terminal = false;
    })
  ];

  meta = with lib; {
    description = "EasyTier GUI - A visual desktop application for EasyTier";
    longDescription = ''
      EasyTier GUI is the official visual desktop application for EasyTier.
      It provides a user-friendly interface for managing EasyTier networks,
      including network configuration, peer management, and real-time monitoring.
    '';
    homepage = "https://github.com/EasyTier/EasyTier";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = with lib.platforms; unix ++ windows;
    mainProgram = "easytier-gui";
  };
})
