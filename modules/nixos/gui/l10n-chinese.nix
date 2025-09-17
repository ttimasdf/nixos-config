{ config, lib, pkgs, ... }:

let
  cfg = config.rabit.modules.gui.l10n-chinese;
in {
  options.rabit.modules.gui.l10n-chinese.enable = lib.mkEnableOption "Localization: Chinese";
  config = lib.mkIf cfg.enable {
    # https://nixos.wiki/wiki/Fonts
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        sarasa-gothic         # Chinese font
        #noto-fonts
        nerd-fonts.noto
        noto-fonts-cjk-sans   # CJK font
        noto-fonts-emoji
        liberation_ttf        # include serif, sans serif, mono
        nerd-fonts.liberation
        #fira-code
        nerd-fonts.fira-code
        fira-code-symbols
        #mplus-outline-fonts.githubRelease  # Japanese font
      ];

      # enable /run/current-system/sw/share/X11/fonts
      fontDir.enable = true;

      fontconfig = {
        #useEmbeddedBitmaps = true;        # fix Noto Color Emoji in Firefox
        defaultFonts = {
          serif = [  "Liberation Serif" "Noto Serif CJK SC" ];
          sansSerif = [ "Liberation Sans" "Sarasa UI SC" "Noto Sans CJK SC" ];
          monospace = [ "FiraCode Nerd Font" "Sarasa Mono SC" "Noto Sans Mono CJK SC" ];
        };
      };
    };

    i18n.inputMethod = {
      type = "fcitx5";
      enable = true;
      fcitx5.waylandFrontend = true;
      fcitx5.addons = with pkgs; [
        fcitx5-gtk             # alternatively, kdePackages.fcitx5-qt
        fcitx5-chinese-addons  # table input method support
        fcitx5-nord            # a color theme
      ];
    };
  };
}
