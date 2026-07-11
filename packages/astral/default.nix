{
  lib,
  stdenv,
  flutter338,
  rustPlatform,
  fetchFromGitHub,
  runCommand,
  makeDesktopItem,
  copyDesktopItems,
  writeText,
  libayatana-appindicator,
  protobuf,
  gdkScale ? 2,
}:

let
  pname = "astral";
  version = "2.7.1";

  src = fetchFromGitHub {
    owner = "ldoubil";
    repo = "astral";
    tag = "v${version}";
    hash = "sha256-4oaYNzf6khp7KIu6qj+N+C7GIH3fiSBLswC8jFZse3k=";
    fetchSubmodules = true;
  };

  rustDep = rustPlatform.buildRustPackage {
    inherit pname version src;

    sourceRoot = "${src.name}/rust";

    cargoHash = "sha256-FaqxEsu/+9TjnebWNNShcSbX5l4ebBQljz0jjrV+nUw=";

    nativeBuildInputs = [
      protobuf
      rustPlatform.bindgenHook
    ];

    passthru.libraryPath = "lib/librust_lib_astral.so";

    meta.platforms = [ "x86_64-linux" ];
  };
in
flutter338.buildFlutterApplication {
  inherit pname version src;

  patches = [
    ./patches/0001-feat-temporarily-disable-HitokotoCard-widget.patch
    ./patches/0002-chore-remove-linux-root-privilege-check.patch
  ];

  # The upstream pubspec.lock uses Chinese mirror (pub.flutter-io.cn).
  # autoPubspecLock is evaluated at Nix eval time (IFD), so we produce a
  # patched pubspec.lock derivation before it's consumed.
  autoPubspecLock = runCommand "astral-pubspec-lock" { } ''
    sed 's|https://pub.flutter-io.cn|https://pub.dev|g' ${src}/pubspec.lock > $out
  '';

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
    cp $out/app/${pname}/data/flutter_assets/assets/logo.png $out/share/pixmaps/astral.png
  '';

  extraWrapProgramArgs = ''
    --prefix LD_LIBRARY_PATH : $out/app/${pname}/lib
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "astral";
      desktopName = "Astral";
      comment = "Astral is an Easytier desktop client";
      exec = "astral %u";
      icon = "astral";
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
    homepage = "https://github.com/ldoubil/astral";
    license = licenses.gpl3;
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "astral";
  };
}
