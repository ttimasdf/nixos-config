{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  makeWrapper,
  libgcc,
  libayatana-appindicator,
  pkexecPath ? "/run/wrappers/bin/pkexec",
  gdkScale ? 2,
}:

stdenv.mkDerivation rec {
  pname = "astral";
  version = "2.7.1";

  src = fetchurl {
    url = "https://github.com/ldoubil/astral/releases/download/v${version}/astral-linux-x64.tar.gz";
    hash = "sha256-vMcnKqEdVfFaGwhJRaR9oH+ncaF/Clon6tN+SjMdkdw=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    makeWrapper
  ];

  # The tarball unpacks directly into the current directory (no single root folder)
  sourceRoot = ".";

  buildInputs = [
    libgcc.lib
    libayatana-appindicator
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/astral
    # DO NOT `cp -R . $out/xxx`
    # otherwize nativeBuildInputs and src will be included as dependencies in the final derivation
    cp -r astral data lib/ $out/opt/astral/

    # Install icon
    mkdir -p $out/share/pixmaps
    cp $out/opt/astral/data/flutter_assets/assets/logo.png $out/share/pixmaps/astral.png

    # Create wrapper script for bin
    mkdir -p $out/bin
    makeWrapper $out/opt/astral/astral $out/bin/${pname} \
      --set GDK_SCALE "${lib.toString gdkScale}" \
      --set GDK_DPI_SCALE "${lib.strings.floatToString (1.0 / gdkScale)}"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "astral";
      desktopName = "Astral";
      comment = "Astral is an Easytier desktop client";
      exec = "${pkexecPath} astral %u";
      icon = "astral";
      terminal = false;
      type = "Application";
      categories = [ "Network" ];
      startupNotify = true;
      keywords = [ "Easytier" "VPN" "Network" "Proxy" ];
    })
  ];

  meta = with lib; {
    description = "Astral desktop client";
    homepage = "https://github.com/ldoubil/astral";
    license = licenses.gpl3;
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "astral";
  };
}
