{
  lib,
  stdenv,
  requireFile,
  buildFHSEnv,
  appimageTools,
  makeFontsConf,
  dpkg,
  qt5,
  gtk3,
  glib,
  zlib,
  libusb1,
  libevdev,
  libinput,
  libpulseaudio,
  libopus,
  libtiff-abi5,
  libxcb,
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
    pname = "${pname}-unpacked";
    inherit version src;

    nativeBuildInputs = [ dpkg ];

    dontUnpack = true;
    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      dpkg-deb -x "$src" "$out"

      runHook postInstall
    '';
  };
in
buildFHSEnv (appimageTools.defaultFhsEnvArgs // {
  inherit pname version;

  executableName = "wuying";

  targetPkgs = pkgs: (with pkgs; appimageTools.defaultFhsEnvArgs.targetPkgs pkgs ++ [
    unpacked
    qt5.qtbase
    qt5.qtwebengine
    # gtk3
    # glib
    # libusb1
    # zlib
    libevdev
    libinput
    # libpulseaudio
    libopus
    libtiff-abi5
    libxcb
  ]);

  profile = ''
    # unset QT_PLUGIN_PATH
    # unset QML2_IMPORT_PATH
    export LD_LIBRARY_PATH="/opt/wuying/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export FONTCONFIG_FILE=${makeFontsConf { fontDirectories = [ ]; }}
  '';

  extraBwrapArgs = [ "--ro-bind ${unpacked}/opt /opt" ];

  # runScript = "/opt/wuying/bin/wuying";
  # debug FHS env running ./result/bin/wuying with bash
  runScript = "bash";

  extraInstallCommands = ''
    cp -rT ${unpacked}/usr/share $out/share

    substituteInPlace $out/share/applications/wuying.desktop \
      --replace-fail "Exec=env LD_LIBRARY_PATH=/opt/wuying/lib /opt/wuying/bin/wuying" "Exec=wuying"
  '';

  passthru = {
    inherit unpacked;
  };

  meta = with lib; {
    description = "Wuying Cloud Desktop - Alibaba Cloud productivity tool";
    homepage = "https://www.aliyun.com/product/wuying";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "wuying";
    maintainers = [ ];
  };
})
