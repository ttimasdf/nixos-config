{
  lib,
  fetchFromGitHub,
  buildGoModule,
  pinentry-qt,
}:

buildGoModule {
  pname = "fido-linux-id";
  version = "0-unstable-2025-12-26";

  src = fetchFromGitHub {
    owner = "matejsmycka";
    repo = "linux-id";
    rev = "c3d2d9e8dab8bc883af123c83a83c41b71d4fb7c";
    hash = "sha256-LkT/WgkIXVrUf0eYLaTTrsBaUy4qg/t3ylDLw5sfccY=";
  };

  vendorHash = "sha256-Aublc4nPudtXO5oPtfBlyE/L0c3DniYHH3M4J1lfoBE=";

  buildInputs = [
    pinentry-qt
  ];

  ldFlags = [
    "-s "
    "-w"
  ];

  meta = {
    description = "WebAuthn/U2F token protected by a TPM";
    homepage = "https://github.com/matejsmycka/linux-id";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ matejsmycka ];
    mainProgram = "linux-id";
  };
}
