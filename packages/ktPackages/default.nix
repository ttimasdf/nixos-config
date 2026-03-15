{
  lib,
  callPackage,
  python3,
  fetchPypi,
  cudaPackages,
}:

let
  kt-kernel = callPackage ./kt-kernel.nix {
    inherit python3 fetchPypi;
  };

  sglang-kt = callPackage ./sglang-kt.nix {
    inherit python3 fetchPypi;
  };
in
lib.recurseIntoAttrs {
  inherit kt-kernel sglang-kt;

  ktransformers = callPackage ./ktransformers.nix {
    inherit python3 fetchPypi kt-kernel sglang-kt;
  };
}
