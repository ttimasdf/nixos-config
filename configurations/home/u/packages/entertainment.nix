{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Emulator
    ryubing
  ];
}
