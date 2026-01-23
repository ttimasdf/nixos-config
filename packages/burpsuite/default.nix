# The original Burp Suite package is defined by buildFHSEnv, which is not overridable.
# Therefore, we are writing our own.
# Reference:
# https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/bu/burpsuite/package.nix
{
  lib,
  stdenv,
  fetchurl,
  jdk,
  runtimeShell,
  makeDesktopItem,
  unzip,
  copyDesktopItems,
  makeWrapper,
  proEdition ? true,
  gdkScale ? "2",
}:
let
  product =
    if proEdition then
      {
        productName = "pro";
        productDesktop = "Burp Suite Professional Edition";
        hash = "sha256-IwseGPMpdaNVCqHg8BrQ+NHLle9ltCQNMUL1m+OTusA=";
      }
    else
      {
        productName = "community";
        productDesktop = "Burp Suite Community Edition";
        hash = "sha256-+mqGMwCzDRu5Trq8S+K5RGm2rcaZBWkclm3bKLJIRD4=";
      };
  description = "Integrated platform for performing security testing of web applications";
  loader = builtins.path {
    name = "burploader";
    path = ./loader;
  };
in
stdenv.mkDerivation rec {
  pname = "burpsuite";
  version = "2025.11.6";

  src = fetchurl {
    name = "burpsuite-${product.productName}-${version}.jar";
    urls = [
      "https://portswigger-cdn.net/burp/releases/download?product=${product.productName}&version=${version}&type=Jar"
      "https://portswigger.net/burp/releases/download?product=${product.productName}&version=${version}&type=Jar"
      "https://web.archive.org/web/https://portswigger.net/burp/releases/download?product=${product.productName}&version=${version}&type=Jar"
    ];
    hash = product.hash;
  };

  desktopItems = [
    (makeDesktopItem {
      name = "burpsuite";
      exec = pname;
      icon = pname;
      desktopName = product.productDesktop;
      comment = description;
      categories = [
        "Development"
        "Security"
        "System"
      ];
    })
  ];

  nativeBuildInputs = [ unzip copyDesktopItems makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/burpsuite $out/share/pixmaps
    cp ${src} $out/share/burpsuite/burpsuite_${product.productName}_v${version}.jar
    cp ${loader}/{burploader.jar,.config.ini} $out/share/burpsuite/

    ${unzip}/bin/unzip -p ${src} resources/Media/icon64${product.productName}.png > "$out/share/pixmaps/burpsuite.png"

    makeWrapper ${jdk}/bin/java $out/bin/${pname} \
      --chdir "$out/share/burpsuite" \
      --set GDK_SCALE ${gdkScale} \
      --add-flags "-jar $out/share/burpsuite/burploader.jar"

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    inherit description;
    longDescription = ''
      Burp Suite is an integrated platform for performing security testing of web applications.
      Its various tools work seamlessly together to support the entire testing process, from
      initial mapping and analysis of an application's attack surface, through to finding and
      exploiting security vulnerabilities.
    '';
    homepage = "https://portswigger.net/burp/";
    changelog =
      "https://portswigger.net/burp/releases/professional-community-"
      + replaceStrings [ "." ] [ "-" ] version;
    sourceProvenance = with sourceTypes; [ binaryBytecode ];
    license = licenses.unfree;
    platforms = jdk.meta.platforms;
    hydraPlatforms = [ ];
    maintainers = with maintainers; [
      bennofs
      blackzeshi
      fab
      yechielw
    ];
    mainProgram = "burpsuite";
  };
}
