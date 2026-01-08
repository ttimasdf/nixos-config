{ flake, lib, ... }:

final: prev:
{
  bcachefs-tools = prev.bcachefs-tools.overrideAttrs (oldAttrs: rec {
    # https://github.com/koverstreet/bcachefs-tools/commits/master/
    version = "1.34.0-git-0e8c88c";
    src = final.fetchFromGitHub {
      owner = "koverstreet";
      repo = "bcachefs-tools";
      rev = "0e8c88cd35b9ac3582d831a34ff26c0c1c7cc9b9";
      hash = "sha256-l2D5IuqpqF+K7Kj6amm9wBY+2beD1KFyVQh+3Eb8NLc=";
    };
    cargoDeps = final.rustPlatform.fetchCargoVendor {
      inherit src;
      hash = "sha256-v17x6/ojK4fGqgBBCKKARYOs/8ECT2FXp7ZgGGAUSss=";
    };
  });
}
