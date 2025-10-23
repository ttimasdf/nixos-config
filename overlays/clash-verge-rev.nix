{ flake, lib, ... }:

final: prev:
{
  # Override clash-verge-rev source
  clash-verge-rev = prev.clash-verge-rev.overrideAttrs (oldAttrs: {
    # Replace this with your desired source override
    # Example: using a specific git revision
    version = "2.4.3-git-cc2dc66";
    src = prev.fetchFromGitHub {
      owner = "clash-verge-rev";
      repo = "clash-verge-rev";
      rev = "cc2dc66d5fe949f487e4ca649c2208477d30443a";
      hash = "sha256-UEk9DpE5rMQAtqA4PMKrTF9oe78AFNqOgiemfOap/KI=";
    };
  });
}
