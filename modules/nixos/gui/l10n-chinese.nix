{ config, lib, pkgs, ... }:

let
  cfg = config.rabit.nixos.gui.l10n-chinese;
in {
  options.rabit.nixos.gui.l10n-chinese.enable = lib.mkEnableOption "Localization: Chinese";
  config = lib.mkIf cfg.enable {
    # https://nixos.wiki/wiki/Fonts
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        sarasa-gothic         # Chinese font
        lxgw-wenkai
        maple-mono.NF-CN
        #noto-fonts
        nerd-fonts.noto
        noto-fonts-cjk-sans   # CJK font
        noto-fonts-color-emoji
        liberation_ttf        # include serif, sans serif, mono
        nerd-fonts.liberation
        #fira-code
        nerd-fonts.fira-code
        fira-code-symbols
        #mplus-outline-fonts.githubRelease  # Japanese font

        # Microsoft Fonts
        # https://github.com/nix-community/nur-combined/blob/90a344dfa259d85ae0cd3d11398384d1bb5c1d16/repos/hexadecimalDinosaur/pkgs/ttf-ms-win11/lists.nix#L85-L90
        nur.repos.hexadecimalDinosaur.ttf-ms-win11.default
        nur.repos.hexadecimalDinosaur.ttf-ms-win11.zh-cn
        nur.repos.chillcicada.ttf-ms-win10-sc-sup
      ];

      /**
        https://wiki.nixos.org/wiki/Fonts#Flatpak_applications_can't_find_system_fonts
        enable /run/current-system/sw/share/X11/fonts
        service.flatpak.enable will automatically enable fontDir,
        so not necessarily needed to set true here
       */
      fontDir.enable = true;

      fontconfig = {
        #useEmbeddedBitmaps = true;        # fix Noto Color Emoji in Firefox
        defaultFonts = {
          serif = [  "Liberation Serif" "Noto Serif CJK SC" ];
          sansSerif = [ "Liberation Sans" "Sarasa UI SC" "Noto Sans CJK SC" ];
          monospace = [ "FiraCode Nerd Font" "Sarasa Mono SC" "Noto Sans Mono CJK SC" ];
        };

        localConf = ''
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
          <fontconfig>
            <alias>
              <family>FangSong_GB2312</family>
              <prefer>
                <family>Liberation Serif</family>
                <family>Noto Serif CJK SC</family>
              </prefer>
            </alias>
          </fontconfig>
        '';
      };
    };

    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/tools/inputmethods/fcitx5/with-addons.nix
    i18n.inputMethod = {
      type = "fcitx5";
      enable = true;
      fcitx5.waylandFrontend = true;
      fcitx5.addons = with pkgs; [
        # Addons
        fcitx5-gtk
        kdePackages.fcitx5-qt
        libsForQt5.fcitx5-qt

        # Chinese IME
        fcitx5-rime-ice

        # color theme
        catppuccin-fcitx5
      ];
    };
  };
}
