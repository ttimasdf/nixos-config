{ flake, ... }:

final: prev:
let
  pkgs-qt68 = import (fetchTarball {
    # Descriptive name to make the store path easier to identify
    name = "nixpkgs-qt68";
    url = "https://github.com/NixOS/nixpkgs/archive/c220a1a8f85179b584a1a66432dc77a802cd5148.tar.gz";
    sha256 = "sha256-G6mOGGVIcVhuXwQJHM+UukLpgvbeh2mfEUqSTmUnsYw=";
  }) {
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  # Python Packages Overlay for pyside6 and shiboken6
  # nix-shell -p qt68python312.pkgs.pyside6
  qt68python312 = pkgs-qt68.python3.override {
    # Careful, we're using a different final and prev here!
    packageOverrides = pyfinal: pyprev:
      let
        pkg_qt68pyside6 = pyprev.pyside6.overrideAttrs (oldAttrs:
        let
          packages = with pyprev.qt6; [
            # required
            pyprev.ninja
            pyprev.packaging
            pyprev.setuptools
            qtbase

            # optional
            qtdeclarative
            qtwayland
          ];
          packages_qt_linked = prev.symlinkJoin {
            name = "qt_linked";
            paths = packages;
          };
        in
        {
          buildInputs = (
            if prev.stdenv.hostPlatform.isLinux then
              # qtwebengine fails under darwin
              # see https://github.com/NixOS/nixpkgs/pull/312987
              packages  # ++ [ pyprev.qt6.qtwebengine ]
            else
              pyprev.qt6.darwinVersionInputs
              ++ [
                packages_qt_linked
                prev.cups
              ]
          );
        });
      in
      {
        # https://github.com/NixOS/nixpkgs/blob/2fb006b87f04c4d3bdf08cfdbc7fab9c13d94a15/pkgs/top-level/python-packages.nix#L14263-L14266
        # https://github.com/NixOS/nixpkgs/blob/b3d51a0365f6695e7dd5cdf3e180604530ed33b4/pkgs/development/python-modules/pyside6/default.nix#L108-L120
        pyside6 = pyprev.toPythonModule pkg_qt68pyside6;
      };
  };
in
{
  qt68 = pkgs-qt68.qt6;
  qt68Packages = pkgs-qt68.qt6Packages;

  qt68python312 = qt68python312;

  # nix-shell -p qt68pyside6
  qt68pyside6 = qt68python312.pkgs.pyside6;

  # nix-shell -p qt68shiboken6
  qt68shiboken6 = qt68python312.pkgs.shiboken6;
}
