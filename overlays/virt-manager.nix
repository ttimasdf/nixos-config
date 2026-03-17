{ flake, ... }:

final: prev:
{
  virt-manager = prev.virt-manager.overrideAttrs (oldAttrs: rec {
    buildInputs = oldAttrs.buildInputs ++ [ final.libayatana-appindicator ];
  });
}
