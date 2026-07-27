{
  lib,
  stdenv,
  requireFile,
  dpkg,
  buildFHSEnv,
  appimageTools,
  writeShellScript,
  curl,
}:

let
  pname = "bizconf-vc";
  version = "4.2.441";

  src = requireFile {
    name = "BizconfVC-amd64.deb";
    hash = "sha256-FaNrdGs9pf2m/8ybCT3w1a8KGqMq21UdDkLNaMhFXLY=";
    message = ''
      Please place BizconfVC-amd64.deb in the Nix store:
      $ nix-store --add-fixed sha256 /path/to/BizconfVC-amd64.deb
    '';
  };

  unpacked = stdenv.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [ dpkg ];

    unpackPhase = ''
      dpkg-deb -x "$src" .
    '';

    installPhase = ''
      mkdir -p "$out/share"
      cp -r usr/share/BizconfVC "$out/share/"
      cp -r usr/share/applications "$out/share/"
      cp -r usr/share/icons "$out/share/"
    '';
  };

  meta = with lib; {
    description = "BizConf Cloud video conferencing client";
    homepage = "https://meetingnext.bizvideo.cn/userportal/download?sitesign=bvmeetingnext";
    license = licenses.unfree;
    mainProgram = "BizconfVC";
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
        alsa-lib
        libpulseaudio
        libusb1
        libva
        libv4l
        qt5.qtbase
        qt5.qtmultimedia
        qt5.qtsvg
        systemd
      ]);

    runScript = writeShellScript "BizconfVC" ''
      export LD_LIBRARY_PATH="${curl.out}/lib:${unpacked}/share/BizconfVC''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      cd "${unpacked}/share/BizconfVC"
      exec ./BizconfVC "$@"
    '';

    extraInstallCommands = ''
      mkdir -p "$out/share"
      cp -r ${unpacked}/share/applications "$out/share/"
      cp -r ${unpacked}/share/icons "$out/share/"

      substituteInPlace "$out/share/applications/BizconfVC.desktop" \
        --replace-fail "Exec=BizconfVC %u" "Exec=$out/bin/BizconfVC %u"
    '';
  }
)
