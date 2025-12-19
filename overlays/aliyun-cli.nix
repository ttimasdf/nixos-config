{ flake, lib, ... }:

final: prev:
{
  aliyun-cli = prev.aliyun-cli.overrideAttrs (oldAttrs: {
    pname = "aliyun-cli";
    version = "3.2.1";

    src = prev.fetchFromGitHub {
        owner = "aliyun";
        repo = "aliyun-cli";
        tag = "v${oldAttrs.version}";
        hash = "sha256-9yjDQ+EDUMp2bdFuVOf8rolo4VWc0Oaf3kw3S0eNuAA=";
        fetchSubmodules = true;
    };
  });
}
