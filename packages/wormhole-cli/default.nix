{
  lib,
  fetchFromGitHub,
  pkg-config,
  rustPlatform,
  openssl,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "wormhole-cli";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "trumank";
    repo = "wormhole-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-GeeQEvDKQu/ijFDI8R2ljvQ2mhok2tsc5p86qugqje8=";
  };

  cargoHash = "sha256-wfHsSf+HhqhkZqhjRnFTBgrziwXuEHGYIytefh4N0dc=";

  buildInputs = [ openssl ];
  nativeBuildInputs = [ pkg-config ];

  cargoTestFlags = [
    # No internet access is allowed in nix build process
    "-- --skip=tests::test_upload_download_various_sizes"
  ];

  meta = {
    description = "Command-line tool for wormhole.app - upload, download, and inspect files";
    homepage = "https://github.com/trumank/wormhole-cli";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
})
