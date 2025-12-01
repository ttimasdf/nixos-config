{ lib, stdenv, fetchFromGitHub, cmake, uhd, fftw, mbedtls, boost, libconfig, lksctp, glib, systemd, curl, qt5, python3 }:

stdenv.mkDerivation rec {
  pname = "LTESniffer";
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = "SysSec-KAIST";
    repo = pname;
    rev = "v${version}";
    # The README mentions submodules are used, so we need to fetch them.
    # However, a quick look at .gitmodules shows srsran_4g, which is not used anymore.
    # The current code uses a vendored srsran version.
    # If build fails due to missing submodules, we can add `fetchSubmodules = true;`
    hash = lib.fakeHash; # placeholder
  };

  nativeBuildInputs = [
    cmake
    python3 # for scripts
  ];

  buildInputs = [
    uhd
    fftw
    mbedtls
    boost
    libconfig
    lksctp
    glib
    systemd # for libudev
    curl
    qt5.qtbase
    qt5.qtdeclarative
    qt5.qtcharts
  ];

  # The executable is created in <build-dir>/src/LTESniffer
  # We need to manually install it.
  installPhase = ''
    runHook preInstall
    install -Dm755 src/LTESniffer $out/bin/LTESniffer
    runHook postInstall
  '';

  meta = with lib; {
    description = "An Open-source LTE Downlink/Uplink Eavesdropper";
    homepage = "https://github.com/SysSec-KAIST/LTESniffer";
    license = licenses.unfree; # No license specified, assume unfree
    maintainers = with maintainers; [ ]; # Add maintainer if you want
    platforms = platforms.linux;
  };
}
