{ pkgs, ... }:
{
  home.packages = with pkgs; [
    uhd # USRP Hardware Driver
  ];
}
