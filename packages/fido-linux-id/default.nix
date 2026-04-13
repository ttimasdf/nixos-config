{
  lib,
  fetchFromGitHub,
  buildGoModule,
  additionalSites ? [],
}:

buildGoModule (finalAttrs: {
  pname = "fido-linux-id";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "matejsmycka";
    repo = "linux-id";
    rev = "v${finalAttrs.version}";
    hash = "sha256-GIeMqbTkSiVJdTbvmB9WDx00odlVXUIf0tm2RYcq1zU=";
  };

  vendorHash = "sha256-HwLcsjzaFqc0aQrTCoSUdes6ZlnsNZJCdtjwucFyOQ4=";

  ldFlags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "WebAuthn/U2F token protected by a TPM";
    homepage = "https://github.com/matejsmycka/linux-id";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ matejsmycka ];
    mainProgram = "linux-id";
  };
})
