{ pkgs ? import <nixpkgs> {} }:

(pkgs.buildFHSEnv {
  name = "binaryninja-env";
  targetPkgs = pkgs: (with pkgs; [
    dbus
    fontconfig
    freetype
    glib
    libGL
    libGLU
    libxkbcommon
    libxml2
    libxcb-cursor
    wayland
    zlib
  ]) ++ (with pkgs.kdePackages; [
    qtbase
    qtdeclarative
    qtwayland
  ]) ++ (with pkgs.xorg; [
    libX11
    libXi
    libXrender
    xcbutilimage
    xcbutilkeysyms
    xcbutilrenderutil
    xcbutilwm
  ]);
  # multiPkgs = pkgs: (with pkgs; [
  #   udev
  #   alsa-lib
  # ]);
  runScript = "bash";
}).env
