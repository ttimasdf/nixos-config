{ flake, lib, ... }:

final: prev:
{
  # Fix wpsoffice-cn with fcitx input method
  # workaround: https://wszqkzqk.github.io/2024/03/09/WPS-Fcitx5/
  wpsoffice-cn-fixup = prev.wpsoffice-cn.overrideAttrs (oldAttrs: {
    preInstallPhases = [ "fixLauncherFcitxPhase" ];
    fixLauncherFcitxPhase = ''
      for i in $out/share/applications/*; do
        substituteInPlace $i \
          --replace-fail Exec= 'Exec=env GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx '
      done
    '';
  });
}
