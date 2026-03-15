{
  lib,
  python3,
  fetchPypi,
}:

let
  source = import ./source.nix { inherit fetchPypi; };
in
python3.pkgs.buildPythonPackage rec {
  pname = "kt-kernel";
  inherit (source) version;
  src = source.kt-kernel;

  format = "wheel";

  dependencies = with python3.pkgs; [
    torch
    safetensors
    compressed-tensors
    numpy
    triton
    gguf
  ];

  meta = {
    description = "High-performance CPU/GPU kernel for KTransformers";
    homepage = "https://github.com/kvcache-ai/ktransformers";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
