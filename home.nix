# https://nixos.wiki/wiki/Home_Manager
# https://github.com/nix-community/home-manager
{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "u";
  home.homeDirectory = "/home/u";

  programs.git = {
    enable = true;
    userName = "ttimasdf";
    userEmail = "opensource@rabit.pw";
  };


  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
