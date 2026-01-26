{ config, lib, pkgs, isDarwin, ... }:
let
  home = "/home/${config.rabit.home.me.username}";
  datadir = "${home}/.config/distrobox/data";
in
{
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.distrobox.enable
  programs.distrobox = {
    enable = true;

    # https://distrobox.it/usage/distrobox-assemble/
    containers = {
      debian = {
        image = "debian:13";
        entry = true;
        nvidia = true;
        volume = lib.join " " [
          "${datadir}/debian/home-local-bin:${home}/.local/bin"
        ];
        additional_packages = "git curl wget build-essential python3-pip nano sudo";
        pre_init_hooks = [
          "export SHELL=/bin/bash"
          "sed -i -E 's@https?://((deb|security).debian.org|(archive|security).ubuntu.com)@http://mirrors.pku.edu.cn@g' /etc/apt/sources.list.d/*.sources"
        ];
        init_hooks = [
          "ln -sf /usr/bin/distrobox-host-exec /usr/local/bin/podman"
        ];
      };

      alpine = {
        image = "alpine:latest";
        entry = true;
        volume = lib.join " " [
          "${datadir}/alpine/home-local-bin:${home}/.local/bin"
        ];
        additional_packages="git build-base";
        pre_init_hooks = [
          "sed -i 's#https\?://dl-cdn.alpinelinux.org/alpine#https://mirrors.tuna.tsinghua.edu.cn/alpine#g' /etc/apk/repositories"
        ];
      };
    };
  };

  home.packages = with pkgs; [
    distrobox-tui
  ];
}
