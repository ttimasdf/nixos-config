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

        # Microsoft Fonts
        corefonts
        vista-fonts
        vista-fonts-chs
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
