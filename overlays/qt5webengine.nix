{ flake, ... }:

final: prev:
let
  # qt5.qtwebengine: drop by LordGrimmauld · Pull Request #480196 · NixOS/nixpkgs https://github.com/NixOS/nixpkgs/pull/480196
  pkgs-qt5webengine = import (fetchTarball {
    # Descriptive name to make the store path easier to identify
    name = "nixpkgs-qt5webengine";
    # the parent commit of https://github.com/NixOS/nixpkgs/commit/c3e30f8ab21a70116a7f189b6b3fa9d7017b717d
    url = "https://github.com/NixOS/nixpkgs/archive/7124eb5c3e1fe1512fcdbe3d87a71724807d2660.tar.gz";
    sha256 = "sha256:1prb8p4f8x4an3ym4v4rjd2mqnzbwkdimrwiprcfk4hdbj86yf3v";
  }) {
    system = prev.system;
    config.allowUnfree = true;
    config.permittedInsecurePackages = [
      final.lib.warn "Enabling insecure package qtwebengine-5.15.19 due to unicom-cloud-desktop dependency"
        "qtwebengine-5.15.19"
    ];
  };
in
{
  qt5w = pkgs-qt5webengine.qt5;
  qt5wPackages = pkgs-qt5webengine.qt5Packages;
}
