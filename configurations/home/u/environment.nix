{ config, lib, pkgs, isDarwin, ... }:
{
  # Fix display scaling for Avalonia apps e.g. ryubing
  home.sessionVariables = {
    AVALONIA_GLOBAL_SCALE_FACTOR = 2;
  };
}