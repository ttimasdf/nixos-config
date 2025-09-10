{ pkgs, ... }:
{
  # https://nixos.wiki/wiki/Flatpak
  services.flatpak.enable = true;
  #systemd.services.flatpak-repo = {
  #  wantedBy = [ "multi-user.target" ];
  #  path = [ pkgs.flatpak ];
  #  script = ''
  #    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  #  '';
  #};

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    # SysAdmin
    kdiff3
    freerdp
    hardinfo2
  ];
}
