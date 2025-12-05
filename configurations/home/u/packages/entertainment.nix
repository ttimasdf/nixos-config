{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Emulator
    ryubing

    # Lossless Scaling Frame Generation on Linux
    lsfg-vk
    lsfg-vk-ui
  ];
}
