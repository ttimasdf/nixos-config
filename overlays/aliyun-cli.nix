{ flake, lib, ... }:

final: prev:
{
  aliyun-cli = prev.aliyun-cli.overrideAttrs (oldAttrs: {
    pname = "aliyun-cli";
    version = "3.2.2";

    src = prev.fetchFromGitHub {
        owner = "aliyun";
        repo = "aliyun-cli";
        tag = "v${oldAttrs.version}";
        hash = "sha256-MIVhESm/5UJxUyN4ZnFLmVKX+2VCBjT33dIbsae3yVA=";
        fetchSubmodules = true;
    };
  });
}
