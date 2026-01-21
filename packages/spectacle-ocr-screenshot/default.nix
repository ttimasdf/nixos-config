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
  makeDesktopItemExtended,
}:

stdenv.mkDerivation rec {
  pname = "spectacle-ocr-screenshot";
  version = "0.3.0";

  desktopItem = makeDesktopItemExtended {
    name = "spectacle-ocr-screenshot";
    desktopName = "Spectacle OCR Screenshot";
    localizedNames = {
      "zh_CN" = "Spectacle OCR 截图";
      "zh_TW" = "Spectacle OCR 截圖";
      "ja" = "Spectacle OCR スクリーンショット";
    };
    genericName = "Screenshot OCR Tool";
    localizedGenericNames = {
      "zh_CN" = "截图OCR工具";
      "zh_TW" = "截圖OCR工具";
      "ja" = "スクリーンショットOCRツール";
    };
    comment = "Take screenshots with OCR and QR code detection";
    localizedComments = {
      "zh_CN" = "使用OCR和二维码识别功能截图";
      "zh_TW" = "使用OCR和QR碼辨識功能截圖";
      "ja" = "OCRとQRコード検出機能付きスクリーンショット";
    };
    exec = "spectacle-ocr-screenshot --lang=chs+eng";
    icon = "spectacle";
    type = "Application";
    categories = [ "Qt" "KDE" "Utility" ];
    keywords = [ "screenshot" "ocr" "qr" "text" "recognition" ];
    localizedKeywords = {
      "zh_CN" = [ "截图" "文字识别" "二维码" "OCR" ];
      "zh_TW" = [ "截圖" "文字辨識" "QR碼" "OCR" ];
      "ja" = [ "スクリーンショット" "OCR" "文字認識" "QRコード" ];
    };
    startupNotify = false;
    extraConfig = {
      "X-KDE-Shortcuts" = "Meta+Shift+O";
    };
    actions = {
      EnglishOnly = {
        name = "OCR Screenshot (English Only)";
        localizedNames = {
          "zh_CN" = "OCR截图（仅英文）";
          "zh_TW" = "OCR截圖（僅英文）";
          "ja" = "OCRスクリーンショット（英語のみ）";
        };
        exec = "spectacle-ocr-screenshot --lang=eng";
      };
      DisableQR = {
        name = "OCR Screenshot (No QR Code Recognition)";
        localizedNames = {
          "zh_CN" = "OCR截图（无二维码识别）";
          "zh_TW" = "OCR截圖（無QR碼辨識）";
          "ja" = "OCRスクリーンショット（QRコード認識なし）";
        };
        exec = "spectacle-ocr-screenshot --lang=chs+eng --no-qr";
      };
    };
  };

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
