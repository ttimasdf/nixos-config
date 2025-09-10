{
  imports = [
    ./kde.nix
    ./l10n-chinese.nix
    ./gui-applications.nix
  ];
  services.xserver.enable = true;
}
