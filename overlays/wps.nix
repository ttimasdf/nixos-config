{ flake, lib, ... }:

final: prev:
let
  nixpkgs-stable = import flake.inputs.nixpkgs-stable {
    system = prev.system;
    config.allowUnfree = true;
  };
in
{
  # Fix wpsoffice-cn with fcitx input method
  # workaround: https://wszqkzqk.github.io/2024/03/09/WPS-Fcitx5/
  # package version: 12.1.0.17900 from nixos-25.05 https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/wp/wpsoffice-cn/package.nix
  # installPhase: https://github.com/NixOS/nixpkgs/blob/e643668fd71b949c53f8626614b21ff71a07379d/pkgs/by-name/wp/wpsoffice-cn/package.nix#L108-L127
  wpsoffice-cn-fixup = nixpkgs-stable.wpsoffice-cn.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
    postFixup = ''
      # Wrap WPS Office executables with fcitx environment variables
      for prog in $out/bin/wps $out/bin/wpp $out/bin/et $out/bin/wpspdf; do
        if [ -f "$prog" ]; then
          wrapProgram "$prog" \
            --set GTK_IM_MODULE fcitx \
            --set QT_IM_MODULE fcitx \
            --set XMODIFIERS "@im=fcitx"
        fi
      done
    '';
  });
}
