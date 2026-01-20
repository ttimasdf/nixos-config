{
  lib,
  stdenv,
  fetchFromGitHub,
  qt6,
  cmake,
  pkg-config,
  tesseract,
  leptonica,
  zxing-cpp,
}:

stdenv.mkDerivation rec {
  pname = "spectacle-ocr-screenshot";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "funinkina";
    repo = "spectacle-ocr-screenshot";
    rev = version;
    hash = "sha256-XPKNwXHhzDgPxATxOqVy2QiKP2M7HjcqQ5JUAsnevhk=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    tesseract
    leptonica
    zxing-cpp
    # kdePackages.spectacle   # Spectacle is a runtime dependency
  ];

  # Use qmake project file
  qmakeFlags = [
    "simple.pro"
  ];

  # Help the linker find ZXing library
  NIX_LDFLAGS = [
    "-lZXing"
  ];

  # Ensure CMake can find ZXing
  cmakeFlags = [
    "-DZXing_DIR=${zxing-cpp}/lib/cmake/ZXing"
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 spectacle-ocr-screenshot $out/bin/spectacle-ocr-screenshot
    runHook postInstall
  '';

  meta = with lib; {
    description = "Automatically OCR screenshots taken with KDE Spectacle";
    longDescription = ''
      A Qt application that integrates KDE Spectacle screenshot tool with
      Tesseract OCR to extract text from screenshots as well as QR codes.

      Features:
      - Capture screenshots using KDE's Spectacle tool
      - Extract text from screenshots using Tesseract OCR
      - Decode QR codes from screenshots
      - Display extracted text in a user-friendly interface
      - Support for multiple languages
      - Edit extracted text before saving
      - Copy text to clipboard
      - Save text to file
    '';
    homepage = "https://github.com/funinkina/spectacle-ocr-screenshot";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "spectacle-ocr-screenshot";
  };
}
