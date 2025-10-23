{ config, ... }:

{
  # Enable Nix Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Use Chinese nix-channels mirror
  nix.settings.substituters = [ "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" ];

  # Allow unfree packages for the main system configuration (e.g., NVIDIA drivers)
  nixpkgs.config.allowUnfree = true;
}
