{ config, lib, pkgs, isDarwin, ... }:
{
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.distrobox.enable
  programs.distrobox = {
    enable = true;

    # https://distrobox.it/usage/distrobox-assemble/
    containers = {
      debian = {
        image = "debian:13";
        entry = true;
        additional_packages = "git curl wget build-essential python3-pip nano sudo";
        pre_init_hooks = [
          "sed -i -E 's@https?://((deb|security).debian.org|(archive|security).ubuntu.com)@http://mirrors.pku.edu.cn@g' /etc/apt/sources.list.d/*.sources"
        ];
        init_hooks = [
          "ln -sf /usr/bin/distrobox-host-exec /usr/local/bin/podman"
        ];
      };

      alpine = {
        image = "alpine:latest";
        entry = true;
        additional_packages="git build-base";
      };
    };
  };

  home.packages = with pkgs; [
    distrobox-tui
  ];
}
