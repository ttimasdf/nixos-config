{
  lib,
  python3,
  fetchPypi,
  kt-kernel,
  sglang-kt,
}:

let
  source = import ./source.nix { inherit fetchPypi; };
in
python3.pkgs.buildPythonApplication rec {
  pname = "ktransformers";
  inherit (source) version;
  src = source.ktransformers;

  format = "wheel";

  dependencies = [
    kt-kernel
    sglang-kt
  ];

  meta = {
    description = "Meta-package for KTransformers CPU-GPU heterogeneous inference framework";
    homepage = "https://github.com/kvcache-ai/ktransformers";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "ktransformers";
  };
}
