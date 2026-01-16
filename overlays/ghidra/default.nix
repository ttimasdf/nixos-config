{ flake, ... }:

final: prev:
let
  inherit (flake.inputs.self) rabit-lib;
  inherit (prev) lib stdenv symlinkJoin fetchFromGitHub makeDesktopItem copyDesktopItems;
  ghidra-ida = fetchFromGitHub {
    owner = "NyaMisty";
    repo = "GhidraIDA";
    rev = "c30ea714e3baaf0b4b1124795e08d283a48d6a92";
    sha256 = "sha256-pJtY3QeS9rK/L9zVlHr23wfq93aeJXLMvQTkkov94t0=";
  };
  ghidra-ida-til = fetchFromGitHub {
    owner = "NyaMisty";
    repo = "ghidra_ida_til";
    rev = "85ac9c9bf1f03e5c82d7f38627eb332a43ee0d68";
    sha256 = "sha256-FmwEJquJZhb/EJvzxgwVpQd/Nfy/pmI+4wlP0zn6dL4=";
  };
  ida-icon = ../../common/ida-pro/ida.png;
  custom-extensions = lib.packagesFromDirectoryRecursive {
      callPackage = lib.callPackageWith (prev // {
        inherit (prev.ghidra-extensions) buildGhidraExtension buildGhidraScripts;
        inherit rabit-lib;
      });
      directory = ./extensions;
    };

  pyghidra = prev.python3Packages.buildPythonPackage {
    pname = "pyghidra";
    # version should be in sync with `__version__` field
    # in {ghidra.src}/Ghidra/Features/PyGhidra/src/main/py/src/pyghidra/__init__.py
    version = "2.2.1";
    src = "${prev.ghidra.src}/Ghidra/Features/PyGhidra/src/main/py";
    dependencies = with prev.python3Packages; [ jpype1 tkinter ];

    pyproject = true;
    build-system = [ prev.python3Packages.setuptools ];
  };
in
{
  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/tools/security/ghidra/build.nix
  ghidra-mod = prev.ghidra.overrideAttrs (oldAttrs: {
    pname = oldAttrs.pname + "-mod";
    patches = (oldAttrs.patches or []) ++ rabit-lib.findPatches ./patches;
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ ghidra-ida ghidra-ida-til ];
    preBuildPhases = (oldAttrs.preBuildPhases or []) ++ [ "addGhidraIDAPhase" ];
    preFixupPhases = (oldAttrs.preFixupPhases or []) ++ [ "addIdaTilPhase" "fixHiDPIPhase" ];

    addGhidraIDAPhase = ''
      defaultToolsDir="./Ghidra/Configurations/Public_Release/src/main/resources/defaultTools"

      # Replace CodeBrowser with mistyGhIDA, rename original tool to CodeBrowserClassic
      mv "$defaultToolsDir/CodeBrowser.tool" "$defaultToolsDir/CodeBrowserClassic.tool"
      sed -i -e 's@TOOL_NAME="CodeBrowser"@TOOL_NAME="CodeBrowserClassic"@' "$defaultToolsDir/CodeBrowserClassic.tool"
      cp "${ghidra-ida}/mistyGhIDA.tool" "$defaultToolsDir/CodeBrowser.tool"

      # change mistyGhIDA icon to IDA Pro icon
      cp "${ida-icon}" ./Ghidra/Features/Base/src/main/resources/defaultTools/images/ida.png
      sed -i -e 's@LOCATION="greenDragon24.png"@LOCATION="ida.png"@' "$defaultToolsDir/CodeBrowser.tool"

      # Add new files to certification.manifest
      echo 'src/main/resources/defaultTools/CodeBrowserClassic.tool||GHIDRA||||END|' >> ./Ghidra/Configurations/Public_Release/certification.manifest
      echo 'src/main/resources/defaultTools/images/ida.png||GHIDRA||||END|' >> ./Ghidra/Features/Base/certification.manifest
    '';

    addIdaTilPhase = ''
      cp -R ${ghidra-ida-til}/release $out/lib/ghidra/Ghidra/Features/Base/data/typeinfo/ida
    '';
    # HiDPI Fix:
    # https://gist.github.com/nstarke/baa031e0cab64a608c9bd77d73c50fc6
    fixHiDPIPhase = ''
      sed -i 's|VMARGS_LINUX=-Dsun.java2d.uiScale=1|VMARGS_LINUX=-Dsun.java2d.uiScale=2|g' \
        "$out/lib/ghidra/support/launch.properties"
    '';

    passthru = oldAttrs.passthru // {
      withExtensions =
        f:
        (symlinkJoin {
          name = "${final.ghidra.pname}-with-extensions-${lib.getVersion final.ghidra}";
          paths = (f (prev.ghidra-extensions // custom-extensions));
          nativeBuildInputs = [
            prev.makeBinaryWrapper
          ] ++ lib.optional stdenv.hostPlatform.isDarwin prev.desktopToDarwinBundle;
          postBuild = ''
            # Prevent attempted creation of plugin lock files in the Nix store.
            touch $out/lib/ghidra/Ghidra/.dbDirLock

            for bin in ghidra ghidra-analyzeHeadless; do
              makeWrapper "${final.ghidra}/bin/$bin" "$out/bin/$bin" \
                --set NIX_GHIDRAHOME "$out/lib/ghidra/Ghidra"
            done
            ln -s ${final.ghidra}/share $out/share
          '' + lib.optionalString stdenv.hostPlatform.isDarwin ''
            convertDesktopFiles $prefix
          '';
          inherit (final.ghidra) meta;
        });
    };
  });

  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/tools/security/ghidra/extensions.nix
  ghidra-mod-with-extensions = final.ghidra.withExtensions (exts:
    (with exts; [
      findcrypt
      # ghidra-delinker-extension
      # ghidra-firmware-utils
      # ghidra-golanganalyzerextension
      # ghidraninja-ghidra-scripts
      # gnudisassembler
      # kaiju
      # lightkeeper
      # machinelearning
      ret-sync
      sleighdevtools
      # wasm

      ## Custom Extensions
      ghidraninja-ghidra-scripts
      ghidrassist-mcp
      ghydra-mcp
    ])
  );

  pyghidra = prev.python3Packages.buildPythonApplication {
    inherit (pyghidra) pname version src dependencies pyproject build-system;

    nativeBuildInputs = [
      copyDesktopItems
    ];

    postBuild = ''
      mkdir -p "$out/bin"
      cat <<'HEREDOC' >"$out/bin/pyghidra-venv-init"
      #!/usr/bin/env bash

      export GHIDRA_INSTALL_DIR="${final.ghidra}/lib/ghidra"
      set -ex
      pushd "$HOME/.config/ghidra/ghidra_${final.ghidra.version}_NIX/"
      uv venv --relocatable --clear venv

      cat <<'ENVIRON' >>venv/bin/activate
      export GHIDRA_INSTALL_DIR="${final.ghidra}/lib/ghidra"
      ENVIRON

      source venv/bin/activate
      pushd "$GHIDRA_INSTALL_DIR"
      uv pip install -f Ghidra/Features/PyGhidra/pypkg/dist/ pyghidra
      uv pip install -f docs/ghidra_stubs ghidra-stubs
      HEREDOC

      chmod +x "$out/bin/pyghidra-venv-init"
    '';

    postFixup = ''
      for bin in pyghidra pyghidraw; do
        wrapProgram "$out/bin/$bin" \
          --set GHIDRA_INSTALL_DIR "${final.ghidra}/lib/ghidra" \
          --set NIX_GHIDRAHOME "${final.ghidra-mod-with-extensions}/lib/ghidra/Ghidra"
      done
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "pyghidraw";
        exec = "pyghidraw";
        icon = "ghidra";
        desktopName = "Ghidra (PyGhidra)";
        genericName = "Ghidra Software Reverse Engineering Suite (PyGhidra Mode)";
        categories = [ "Development" ];
        terminal = false;
        startupWMClass = "ghidra-Ghidra";
      })
    ];
  };

  python3 = prev.python3.override {
    packageOverrides = pyfinal: pyprev: {
      inherit pyghidra;
    };
  };

  ghidra-custom-extensions = custom-extensions;
}
