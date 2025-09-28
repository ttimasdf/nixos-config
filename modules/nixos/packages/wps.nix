{ config, lib, pkgs, ... }:
let
  # https://nixos.wiki/wiki/FAQ/Pinning_Nixpkgs
  # wpsoffice-cn version 12.1.0.17900
  # https://lazamar.co.uk/nix-versions/?package=wpsoffice-cn&version=12.1.0.17900&fullName=wpsoffice-cn-12.1.0.17900&keyName=wpsoffice-cn&revision=e6f23dc08d3624daab7094b701aa3954923c6bbb&channel=nixpkgs-unstable#instructions
  pkgs-20250908 = import (fetchTarball {
    name = "nixpkgs-unstable-20250908";
    url = "https://github.com/NixOS/nixpkgs/archive/fc2e2eeb82edd98b038c2841ebf7016d3a9ccfe4.tar.gz";
    sha256 = "03ip4yx2wlf7fg1hs7qw7csijxlb0mb2i3gg98wn9n4m9kcxpbws";
  }) {
    system = pkgs.system;
    config.allowUnfree = true;
  };
  # pkgs-20250908 = import (builtins.fetchGit {
  #     # Descriptive name to make the store path easier to identify
  #     name = "nixpkgs-unstable-20250908";
  #     url = "https://github.com/NixOS/nixpkgs/";
  #     ref = "refs/heads/nixpkgs-unstable";
  #     rev = "fc2e2eeb82edd98b038c2841ebf7016d3a9ccfe4";
  # }) {};
in
{
  # https://nixos.wiki/wiki/Overlays
  nixpkgs.overlays = [
    (final: prev: {
      # Fix wpsoffice-cn
      # https://wszqkzqk.github.io/2024/03/09/WPS-Fcitx5/
      # https://github.com/NixOS/nixpkgs/blob/e643668fd71b949c53f8626614b21ff71a07379d/pkgs/by-name/wp/wpsoffice-cn/package.nix#L108-L127
      wpsoffice-cn-fixup = pkgs-20250908.wpsoffice-cn.overrideAttrs (oldAttrs: {
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
