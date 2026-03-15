{
  lib,
  python3,
  fetchPypi,
}:

let
  source = import ./source.nix { inherit fetchPypi; };
in
python3.pkgs.buildPythonPackage rec {
  pname = "sglang-kt";
  inherit (source) version;
  src = source.sglang-kt;

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
    description = "SGLang backend for KTransformers";
    homepage = "https://github.com/kvcache-ai/ktransformers";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
