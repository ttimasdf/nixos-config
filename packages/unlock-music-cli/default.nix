{
  lib,
  fetchgit,
  buildGoModule,
  nix-update-script,
}:

buildGoModule rec {
  pname = "unlock-music-cli";
  version = "0-unstable-2025-08-12";

  src = fetchgit {
    url = "https://git.um-react.app/um/cli.git";
    rev = "107aa2c3a843e6b30406d45d64789f3c155dd68f";
    hash = "sha256-mPT5H4pIvnCfKeNR0V5ENXEPZtFXFlNIKF+kEtiQ85c=";
  };

  vendorHash = "sha256-ozRvYx6+7MZomiFq1aE39Yu1lFVfgmAmJ7gxDzLyH8M=";

  ldflags =
    let
      # Determine the version string to use in the source code
      appVersion =
        if lib.hasInfix "unstable" version then "git-${builtins.substring 0 10 src.rev}" else version;
    in
    [
      "-s"
      "-w"
      "-X main.AppVersion=${appVersion}"
    ];

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "Unlock Music CLI - Command line tool to unlock encrypted music files";
    homepage = "https://git.um-react.app/um/cli";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "um";
  };
}
