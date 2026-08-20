{ flake, ... }:

final: prev:
let
  inherit (flake.inputs.self) rabit-lib;
in
{
  kdePackages = prev.kdePackages.overrideScope (_kdeFinal: kdePrev: {
    kscreen = kdePrev.kscreen.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ (rabit-lib.findPatches ./patches);
    });
  });
}
