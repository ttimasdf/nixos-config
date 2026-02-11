{
  lib,
  stdenv,
  appimageTools,
  fetchurl,
  curl,
  jq,
  common-updater-scripts,
  writeShellScript,
}:

let
  version = "1.4.6-0206";
  pname = "yakit";

  sources = {
    "x86_64-linux" = fetchurl {
      url = "https://github.com/yaklang/yakit/releases/download/v${version}/Yakit-${version}-linux-amd64.AppImage";
      hash = "sha256-CYe5TBp/jzbsbDMjMbTirnFtdaOtpzKWPOEi9MxXjvk=";
    };
    "aarch64-linux" = fetchurl {
      url = "https://github.com/yaklang/yakit/releases/download/v${version}/Yakit-${version}-linux-arm64.AppImage";
      hash = lib.fakeHash;
    };
  };

  src = (sources.${stdenv.hostPlatform.system} or (throw "yakit ${version} unsupported system: ${stdenv.hostPlatform.system}"));

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

  passthru = {
    inherit sources;
    updateScript = writeShellScript "update-yakit" ''
      set -o errexit
      export PATH="${
        lib.makeBinPath [
          curl
          jq
          common-updater-scripts
        ]
      }"
      NEW_VERSION=$(curl --silent https://api.github.com/repos/yaklang/yakit/releases/latest | jq '.tag_name | ltrimstr("v")' --raw-output)
      if [[ "${version}" = "$NEW_VERSION" ]]; then
          echo "The new version same as the old version."
          exit 0
      fi
      for platform in ${lib.escapeShellArgs meta.platforms}; do
        update-source-version "yakit" "$NEW_VERSION" --ignore-same-version --source-key="passthru.sources.$platform"
      done
    '';
  };

  meta = with lib; {
    description = "A local cross-platform reverse-engineering framework";
    homepage = "https://github.com/yaklang/yakit";
    downloadPage = "https://github.com/yaklang/yakit/releases";
    license = licenses.agpl3Only;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    platforms = builtins.attrNames passthru.sources;
    mainProgram = "yakit";
  };
}
