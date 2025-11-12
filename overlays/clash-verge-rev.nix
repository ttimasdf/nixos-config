{ flake, lib, ... }:

final: prev:
{
  clash-verge-rev = prev.clash-verge-rev.overrideAttrs (oldAttrs: {
    # https://github.com/clash-verge-rev/clash-verge-rev/commits/dev/
    version = "2.4.3-git-cc2dc66";
    src = prev.fetchFromGitHub {
      owner = "clash-verge-rev";
      repo = "clash-verge-rev";
      rev = "cc2dc66d5fe949f487e4ca649c2208477d30443a";
      hash = "sha256-UEk9DpE5rMQAtqA4PMKrTF9oe78AFNqOgiemfOap/KI=";
    };
  });
}
