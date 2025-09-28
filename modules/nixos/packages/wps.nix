{ config, lib, pkgs, ... }:

{
  # https://nixos.wiki/wiki/Overlays
  nixpkgs.overlays = [
    (self: super: {
      # Fix wpsoffice-cn
      # https://wszqkzqk.github.io/2024/03/09/WPS-Fcitx5/
      # https://github.com/NixOS/nixpkgs/blob/e643668fd71b949c53f8626614b21ff71a07379d/pkgs/by-name/wp/wpsoffice-cn/package.nix#L108-L127
      wpsoffice-cn-fixup = super.wpsoffice-cn.overrideAttrs (oldAttrs: {
        installPhase = lib.replaceString "runHook postInstall" ''
          for i in $out/share/applications/*; do
            substituteInPlace $i \
              --replace-fail Exec= 'Exec=env GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx '
          done

          runHook postInstall
        '' oldAttrs.installPhase;
      });
    })
  ];
}
