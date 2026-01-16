{ flake, ... }:

final: prev:
{
  # Fix wpsoffice-cn with fcitx input method
  # workaround: https://wszqkzqk.github.io/2024/03/09/WPS-Fcitx5/
  wpsoffice-cn-fcitx = prev.wpsoffice-cn.overrideAttrs (oldAttrs: {
    pname = oldAttrs.pname + "-fcitx";
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
    postFixup = ''
      # Wrap WPS Office executables with fcitx environment variables
      for prog in $out/bin/wps $out/bin/wpp $out/bin/et $out/bin/wpspdf; do
        if [ -f "$prog" ]; then
          wrapProgram "$prog" \
            --set GTK_IM_MODULE fcitx \
            --set QT_IM_MODULE fcitx \
            --set XMODIFIERS "@im=fcitx"
        fi
      done
    '';
  });
}
