{
  lib,
  stdenv,
  fetchFromGitHub,
  rust,
  rustPlatform,
  pkg-config,
  glib,
  gtk3,
  libsoup_3,
  cargo-tauri,
  fetchNpmDeps,
  npmHooks,
  glib-networking,
  openssl,
  webkitgtk_4_1,
  nodejs,
  wrapGAppsHook4,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "y-agent";
  version = "0-unstable-2026-03-31";

  # Private fetchFromGitHub requires the nix building process (nix-daemon in multi user mode)
  # to have the NIX_GITHUB_PRIVATE_USERNAME and NIX_GITHUB_PRIVATE_PASSWORD env vars set.
  src = fetchFromGitHub {
    owner = "ttimasdf";
    repo = "y-agent";
    rev = "e058c959c0adcc757b9d8d9103f4db310789c4a3";
    sha256 = "sha256-i34ct6zswlYXx9Zz9UcJ5Esx4y4wXQKghtrrHuk+n3M=";
    private = true;
  };

  npmRoot = "./crates/y-gui";
  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) pname version;
    src = "${finalAttrs.src}/crates/y-gui";
    hash = "sha256-W7Gtmt38cZLlQ9+RTGetG4BjWyH615mEJ4HafoFhNrw=";
  };
  npmFlags = [ "--legacy-peer-deps" ];

  cargoLock.lockFile = "${finalAttrs.src}/Cargo.lock";

  nativeBuildInputs = [
    cargo-tauri.hook
    nodejs
    npmHooks.npmConfigHook
    pkg-config
  ] ++ lib.optionals stdenv.hostPlatform.isLinux [
    wrapGAppsHook4
  ];

  buildInputs = [
    glib
    glib-networking
    gtk3
    openssl
    webkitgtk_4_1
    libsoup_3
  ];

  postBuild = ''
    # cargo-tauri builds y-gui only, so we need to build y-agent separately
    ${rust.envVars.setEnv} cargo build "''${cargoFlagsArray[@]}" --bin y-agent
  '';

  postInstall = ''
    # Copy the y-agent binary to the output bin directory
    releaseDir=target/${stdenv.targetPlatform.rust.cargoShortTarget}/${finalAttrs.cargoBuildType}
    mkdir -p $out/bin
    cp $releaseDir/y-agent $out/bin/
  '';

  # Skip flaky test that times out in nix sandbox
  checkFlags = [
    "--skip=hook_handler::tests::handler_tests::test_command_hook_timeout_killed"
  ];

})
