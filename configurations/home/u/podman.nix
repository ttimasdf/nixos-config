{ config, lib, pkgs, osConfig, isDarwin, ... }:
{
  # Configure the global HTTP proxy for the podman service.
  systemd.user.services."podman".Service = lib.mkIf (osConfig.rabit.nixos.http_proxy != null) {
    Environment = [
      "http_proxy=${osConfig.rabit.nixos.http_proxy}"
      "https_proxy=${osConfig.rabit.nixos.http_proxy}"
      "no_proxy=${osConfig.rabit.nixos.no_proxy}"
    ];
  };
}