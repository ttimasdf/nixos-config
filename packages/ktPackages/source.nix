{ fetchPypi }:

rec {
  version = "0.5.2.post1";

  sglang-kt = fetchPypi {
    pname = "sglang_kt";
    inherit version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    hash = "sha256-rf3bYCpX/ZYrrHK4cQbtSFdVmmXOxf7aIUr/AGEsKDA=";
  };

  kt-kernel = fetchPypi {
    pname = "kt_kernel";
    inherit version;
    format = "wheel";
    dist = "cp311";
    python = "cp311";
    abi = "cp311";
    platform = "manylinux_2_34_x86_64.manylinux_2_35_x86_64";
    hash = "sha256-rf3bYCpX/ZYrrHK4cQbtSFdVmmXOxf7aIUr/AGEsKDA=";
  };

  ktransformers = fetchPypi {
    pname = "ktransformers";
    inherit version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    hash = "sha256-+ZC2DFBSrs7UffIty/2r5SRuBxNTYgUV8+orjWQAqFc=";
  };
}
