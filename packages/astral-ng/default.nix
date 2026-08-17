{
  lib,
  stdenv,
  flutter344,
  rustPlatform,
  fetchFromGitHub,
  makeDesktopItem,
  copyDesktopItems,
  writeText,
  libayatana-appindicator,
  protobuf,
}:

let
  pname = "astral-ng";
  version = "0-unstable-2026-08-16";

  src = fetchFromGitHub {
    owner = "ttimasdf";
    repo = "astral-ng";
    rev = "bc4ce43c904c6f521bfcf18dce1cf437f792801c";
    hash = "sha256-G1Y2AQPdRx2HyCK6zyPhAYbgrKecPBcrj9WWxM8rwnw=";
    fetchSubmodules = true;
  };

  rustDep = rustPlatform.buildRustPackage {
    inherit pname version src;

    sourceRoot = "${src.name}/rust";

    cargoHash = "sha256-hpGO7uoR4t65Tawy+4wyETu5j9yCl7Q59rU55cOC4BM=";

    nativeBuildInputs = [
      protobuf
      rustPlatform.bindgenHook
    ];

    passthru.libraryPath = "lib/librust_lib_astral.so";

    meta.platforms = [ "x86_64-linux" ];
  };
in
flutter344.buildFlutterApplication {
  inherit pname version src;

  autoPubspecLock = src + "/pubspec.lock";

  customSourceBuilders = {
    rust_lib_astral =
      { version, src, ... }:
      stdenv.mkDerivation {
        pname = "rust_lib_astral";
        inherit version src;
        inherit (src) passthru;

        postPatch =
          let
            fakeCargokitCmake = writeText "FakeCargokit.cmake" ''
              function(apply_cargokit target manifest_dir lib_name any_symbol_name)
                set("''${target}_cargokit_lib" ${rustDep}/${rustDep.passthru.libraryPath} PARENT_SCOPE)
              endfunction()
            '';
          in
          ''
            cp ${fakeCargokitCmake} rust_builder/cargokit/cmake/cargokit.cmake
          '';

        installPhase = ''
          runHook preInstall

          cp -r . "$out"

          runHook postInstall
        '';
      };
  };

  nativeBuildInputs = [
    copyDesktopItems
  ];

  buildInputs = [
    libayatana-appindicator
  ];

  postInstall = ''
    mkdir -p $out/share/pixmaps
    cp $out/app/${pname}/data/flutter_assets/assets/logo.png $out/share/pixmaps/astral-ng.png
  '';

  extraWrapProgramArgs = ''
    --prefix LD_LIBRARY_PATH : $out/app/${pname}/lib
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "astral-ng";
      desktopName = "Astral-NG";
      comment = "Astral-NG is an Easytier desktop client";
      exec = "astral %u";
      icon = "astral-ng";
      terminal = false;
      type = "Application";
      categories = [ "Network" ];
      startupNotify = true;
      keywords = [ "Easytier" "VPN" "Network" "Proxy" ];
    })
  ];

  passthru = {
    inherit rustDep;
  };

  meta = with lib; {
    description = "Astral desktop client";
    homepage = "https://github.com/ttimasdf/astral-ng";
    license = licenses.gpl3;
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "astral";
  };
}
