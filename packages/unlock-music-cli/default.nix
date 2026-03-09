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
    rev = "589e573b55f4b2d9c50970ebe5f77f1b30ac1e05";
    hash = "sha256-pFzF3f4TDoKanHyG735pYq7gkVP3t+ahBeUhLxsjyrM=";
  };

  vendorHash = "sha256-tiYP4Bivq7qq7aQAZw0lzjuNn1cMEhgTH8Tzi+L8OvA=";

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
