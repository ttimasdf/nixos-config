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

    # https://nixos.wiki/wiki/Overlays
    nixpkgs.overlays = [
      (self: super: {
        # https://github.com/NixOS/nixpkgs/blob/e643668fd71b949c53f8626614b21ff71a07379d/nixos/modules/i18n/input-method/fcitx5.nix#L96-L98
        fcitx5-rime-ice = super.fcitx5-rime.override {
          rimeDataPkgs = [ pkgs.rime-data-ice ];
        };
        # https://github.com/NixOS/nixpkgs/blob/e643668fd71b949c53f8626614b21ff71a07379d/pkgs/by-name/ri/rime-ice/package.nix#L19-L30
        rime-data-ice = super.rime-ice.overrideAttrs (oldAttrs: {
          installPhase = ''
            runHook preInstall

            rm -rf others README.md .git*

            mkdir -p $out/share
            cp -r . $out/share/rime-data

            runHook postInstall
          '';
        });
      })
    ];

    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/tools/inputmethods/fcitx5/with-addons.nix
    i18n.inputMethod = {
      type = "fcitx5";
      enable = true;
      /**
        Set GTK_IM_MODULE and QT_IM_MODULE environment variables by configuring waylandFrontend to false,
        which resolves issues with WPS Office and potentially other X11 applications.
        Reference: https://github.com/NixOS/nixpkgs/blob/5ae3b07d8d6527c42f17c876e404993199144b6a/nixos/modules/i18n/input-method/fcitx5.nix#L144-L148

        HOWEVER,
        Fcitx5 Wayland Diagnose will display the following error message:

        Detect GTK_IM_MODULE and QT_IM_MODULE being set and Wayland Input method frontend is working.
        It is recommended to use Wayland input method frontend.
        For more details see https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland#KDE_Plasma
      */
      fcitx5.waylandFrontend = false;
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
