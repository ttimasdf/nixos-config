{ config, lib, ... }:

{
  # Enable Nix Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Use Chinese nix-channels mirror
  nix.settings.substituters = [ "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" ];

  # Allow unfree packages for the main system configuration (e.g., NVIDIA drivers)
  nixpkgs.config.allowUnfree = true;

  # Configure the global HTTP proxy for the nix-daemon.
  systemd.services."nix-daemon".serviceConfig = lib.mkIf (config.rabit.nixos.http_proxy != null) {
    Environment = [
      "http_proxy=${config.rabit.nixos.http_proxy}"
      "https_proxy=${config.rabit.nixos.http_proxy}"
      "no_proxy=${config.rabit.nixos.no_proxy}"
    ];
  };

}
