/**
  Solution 3: Configure bindfs for fonts/cursors/icons support - Fonts - Official NixOS Wiki
  https://wiki.nixos.org/wiki/Fonts#Solution_3:_Configure_bindfs_for_fonts/cursors/icons_support
 */
{ config, lib, pkgs, ... }:

let
  cfg = config.rabit.nixos.gui.font-dir;
in {
  options.rabit.nixos.gui.font-dir.enable = lib.mkEnableOption "GUI: Font Directory BindFS mountpoints";
  config = lib.mkIf cfg.enable {
    system.fsPackages = [ pkgs.bindfs ];

    fileSystems = let
      mkRoSymBind = path: {
        device = path;
        fsType = "fuse.bindfs";
        options = [ "ro" "resolve-symlinks" "x-gvfs-hide" ];
      };
      aggregated = pkgs.buildEnv {
        name = "system-fonts-and-icons";
        nativeBuildInputs = [ pkgs.mkfontscale ];
        paths = config.fonts.packages ++ (with pkgs; [
          ## Add your cursor themes and icon packages here
          # bibata-cursors
          # gnome.gnome-themes-extra
        ]);
        pathsToLink = [ "/share/fonts" "/share/icons" ];
        ignoreCollisions = true;
        postBuild = ''
          find "$out/share/fonts" -type d -exec ${pkgs.mkfontscale}/bin/mkfontdir {} \;
        '';
      };
    in {
      "/usr/share/fonts" = mkRoSymBind "${aggregated}/share/fonts";
      "/usr/share/icons" = mkRoSymBind "${aggregated}/share/icons";
    };
  };
}
