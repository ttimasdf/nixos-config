{
  lib,
  stdenv,
  appimageTools,
  fetchurl,
}:

let
  version = "1.4.4-1031";
  pname = "yakit";

  srcs = {
    "x86_64-linux" = {
      url = "https://github.com/yaklang/yakit/releases/download/v${version}/Yakit-${version}-linux-amd64.AppImage";
      hash = "sha256-IOW5wajVBmxjTfsyQeBztzA0bVwLTvzX4E5Fu9JVytE=";
    };
    "aarch64-linux" = {
      url = "https://github.com/yaklang/yakit/releases/download/v${version}/Yakit-${version}-linux-arm64.AppImage";
      hash = lib.fakeSha256;
    };
  };

  src = fetchurl (srcs.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}"));

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 rec {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/yakit.desktop $out/share/applications/${pname}.desktop
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${meta.mainProgram}'

    for size in 16 32 48 64 128 256 512; do
      install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/"$size"x"$size"/apps/yakit.png \
        $out/share/icons/hicolor/"$size"x"$size"/apps/${pname}.png
    done
  '';

  meta = with lib; {
    description = "A local cross-platform reverse-engineering framework";
    homepage = "https://github.com/yaklang/yakit";
    downloadPage = "https://github.com/yaklang/yakit/releases";
    license = licenses.agpl3Only;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    platforms = attrNames srcs;
    mainProgram = "yakit";
  };
}
