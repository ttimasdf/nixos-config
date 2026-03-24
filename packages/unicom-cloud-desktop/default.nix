{
  lib,
  stdenv,
  requireFile,
  dpkg,
  buildFHSEnv,
  appimageTools,
  writeShellScript,
}:

let
  pname = "unicom-cloud-desktop";
  version = "7.11.0-wuying";

  src = requireFile {
    name = "unicom-cloud-desktop-${version}.deb";
    hash = "sha256-NdqvQVi9jq4YQFRQQQDU6s6rfVNrl9gYS2yJhnUzcxE=";
    message = ''
      Please download the Unicom Cloud Desktop (Wuying) installer and place it in the store:
      $ nix-prefetch-url file:///path/to/unicom-cloud-desktop-${version}.deb
    '';
  };

  unpacked = stdenv.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [ dpkg ];

    unpackPhase = ''
      dpkg-deb -x $src .
    '';

    installPhase = ''
      mkdir -p $out/opt $out/share
      cp -r opt/wuying $out/opt/
      cp -r usr/share/applications $out/share/
      cp -r usr/share/fonts $out/share/
      cp -r usr/share/icons $out/share/
    '';
  };

  meta = with lib; {
    description = "Wuying Cloud Desktop - Alibaba Cloud productivity tool";
    homepage = "https://www.aliyun.com/product/wuying";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };

in
buildFHSEnv (
  appimageTools.defaultFhsEnvArgs
  // {
    inherit pname version meta;

    targetPkgs =
      pkgs:
      (appimageTools.defaultFhsEnvArgs.targetPkgs pkgs)
      ++ (with pkgs; [
        qt5.qtbase
        qt5.qtwebengine
        libusb1
        libevdev
        libinput
        libpulseaudio
        libopus
        libtiff-abi5
        unpacked
      ]);

    runScript = writeShellScript "wuying" ''
      export LD_LIBRARY_PATH="/opt/wuying/lib:$LD_LIBRARY_PATH"
      exec /opt/wuying/bin/wuying "$@"
    '';

    extraInstallCommands = ''
      mkdir -p $out/share
      cp -r ${unpacked}/share/applications $out/share/
      cp -r ${unpacked}/share/icons $out/share/

      substituteInPlace $out/share/applications/wuying.desktop \
        --replace "Exec=env LD_LIBRARY_PATH=/opt/wuying/lib /opt/wuying/bin/wuying" "Exec=$out/bin/${pname}" \
        --replace "Icon=cloudspace-logo" "Icon=$out/share/icons/hicolor/scalable/apps/cloudspace-logo.png"
    '';
  }
)
