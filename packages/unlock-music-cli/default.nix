{ lib
, buildGoModule
, fetchgit
}:

buildGoModule rec {
  pname = "unlock-music-cli";
  version = "0.2.12";

  src = fetchgit {
    url = "https://git.unlock-music.dev/um/cli.git";
    rev = "v${version}";
    hash = "sha256-v8ODgmcg+e4v7x2dP6hDCDQCYALw57tCayQ4W00yTGw=";
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
