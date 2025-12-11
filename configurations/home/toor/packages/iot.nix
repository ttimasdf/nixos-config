{ pkgs, ... }:
{
  home.packages = with pkgs; [
    pulseview
    # SDR
    uhd # USRP Hardware Driver
  ];
}
