{
  lib,
  stdenv,
  appimageTools,
  fetchurl,
}:

let
  version = "7.11.0";
  pname = "wuying";

  src = fetchurl {
    url = "https://wuying-client-pkg.oss-rg-china-mainland.aliyuncs.com/wuying_uos_kylin_x86_64-${version}-R-20250715.164108%20%281%29.deb";
    hash = lib.fakeHash;
  };

    # 2. Tools needed to build/fix the package
    nativeBuildInputs = [
        pkgs.dpkg
        pkgs.autoPatchelfHook
    ];

    # 3. Libraries the app needs to run (e.g., glibc, openssl)
    buildInputs = [
        pkgs.stdenv.cc.cc.lib
        pkgs.openssl
        # Add other dependencies found via 'ldd' here
    ];

    # 4. Extract and Install
    unpackPhase = ''
        dpkg-deb -x $src .
    '';

    installPhase = ''
        mkdir -p $out
        cp -r usr/* $out/
    '';
    } ;
}
