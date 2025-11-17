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
          paths = config.fonts.packages ++ (with pkgs; [
            ## Add your cursor themes and icon packages here
            # bibata-cursors
            # gnome.gnome-themes-extra
          ]);
          pathsToLink = [ "/share/fonts" "/share/icons" ];
      };
    in {
      "/usr/share/fonts" = mkRoSymBind "${aggregated}/share/fonts";
      "/usr/share/icons" = mkRoSymBind "${aggregated}/share/icons";
    };
  };
}