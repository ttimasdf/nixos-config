{ flake, ... }:

final: prev:
let
  inherit (flake.inputs.self) rabit-lib;
in
{
  # https://github.com/NixOS/nixpkgs/blob/e643668fd71b949c53f8626614b21ff71a07379d/nixos/modules/i18n/input-method/fcitx5.nix#L96-L98
  fcitx5-rime-ice = prev.fcitx5-rime.override {
    rimeDataPkgs = [ final.rime-data-ice ];
  };

  # https://github.com/NixOS/nixpkgs/blob/e643668fd71b949c53f8626614b21ff71a07379d/pkgs/by-name/ri/rime-ice/package.nix#L19-L30
  rime-data-ice = prev.rime-ice.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or []) ++ (rabit-lib.findPatches ./patches);
    postInstall = ''
      mv rime_ice_suggestion.yaml default.yaml
    '';
  });
}
