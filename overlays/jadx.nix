{ flake, lib, ... }:

final: prev:
{
  jadx = prev.jadx.overrideAttrs (oldAttrs: {
    version = "1.5.3";
    src = prev.fetchFromGitHub {
      owner = "skylot";
      repo = "jadx";
      rev = "v${oldAttrs.version}";
      hash = "sha256-+F+PHAd1+FmdAlQkjYDBsUYCUzKXG19ZUEorfvBUEg0=";
    };
  });
}
