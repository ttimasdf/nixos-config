{ pkgs, ... }:
{
  home.packages = with pkgs; [
    openocd       # On-Chip Debugging
    # pulseview     # Signal Analyzer
    # SDR
    uhd           # USRP Hardware Driver
    rkdeveloptool # Rockchip Development Tool
    squashfsTools
    dtc
  ];
}
