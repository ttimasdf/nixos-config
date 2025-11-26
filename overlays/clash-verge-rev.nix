{ flake, lib, ... }:

final: prev:
{
  clash-verge-rev = prev.clash-verge-rev.overrideAttrs (oldAttrs: {
    # https://github.com/clash-verge-rev/clash-verge-rev/commits/dev/
    version = "2.4.3-git-51a7b4f";
    src = prev.fetchFromGitHub {
      owner = "clash-verge-rev";
      repo = "clash-verge-rev";
      rev = "51a7b4fe750e077ad6b373624a4187d827d581a5";
      hash = "sha256-4pTXHgQ6Pjdy53sbEVVv/6GSbITOIewOTCiR8KEV7Hk=";
    };
  });
}
