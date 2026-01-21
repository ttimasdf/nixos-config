{ lib
, buildGoModule
, fetchgit
}:

buildGoModule rec {
  pname = "unlock-music-cli";
  version = "0-unstable-2025-08-12";

  src = fetchgit {
    url = "https://git.unlock-music.dev/um/cli.git";
    rev = "589e573b55f4b2d9c50970ebe5f77f1b30ac1e05";
    hash = "sha256-pFzF3f4TDoKanHyG735pYq7gkVP3t+ahBeUhLxsjyrM=";
  };

  vendorHash = "sha256-tiYP4Bivq7qq7aQAZw0lzjuNn1cMEhgTH8Tzi+L8OvA=";

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  meta = with lib; {
    description = "Unlock Music CLI - Command line tool to unlock encrypted music files";
    homepage = "https://git.unlock-music.dev/um/cli";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "um";
  };
}
