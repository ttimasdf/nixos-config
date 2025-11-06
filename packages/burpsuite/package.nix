{
  lib,
  stdenv,
  fetchurl,
  jre,
  runtimeShell,
  makeDesktopItem,
  unzip,
  copyDesktopItems,
  makeWrapper,
  proEdition ? true,
}:
let
  product =
    if proEdition then
      {
        productName = "pro";
        productDesktop = "Burp Suite Professional Edition";
        hash = "sha256-aLP8jVHuKmp4yzcd1KsgidAhWUxoJo0beGwq/6I4n4A=";
      }
    else
      {
        productName = "community";
        productDesktop = "Burp Suite Community Edition";
        hash = "sha256-HiYdJrnTg0HkCt+lXKkhfGawp/NZQmhH4sGytlpiLU8=";
      };
  description = "Integrated platform for performing security testing of web applications";
  loader = builtins.path {
    name = "burploader";
    path = ./loader;
  };
in
stdenv.mkDerivation rec {
  pname = "burpsuite";
  version = "2025.10.1";

  src = fetchurl {
    name = "burpsuite.jar";
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

    makeWrapper ${jre}/bin/java $out/bin/${pname} \
      --chdir "$out/share/burpsuite" \
      --set GDK_SCALE 2 \
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
    platforms = jre.meta.platforms;
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
