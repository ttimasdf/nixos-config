{
  lib,
  stdenv,
  requireFile,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  makeSanitizedLauncherHook,
  _7zz,
  dbus,
  fontconfig,
  freetype,
  glib,
  libGL,
  libGLU,
  libxkbcommon,
  libxml2,
  wayland,
  xorg,
  qt6Packages,
  python312,
  qt68Packages ? null,
  qt68python312 ? null,
  useQtFromNixpkgs ? false,
}:

let
  _ = lib.asserts.assertMsg (!useQtFromNixpkgs || (qt68Packages != null && qt68python312 != null))
    "qt68Packages and qt68python312 must be provided when useQtFromNixpkgs is true";
  qt6Packages' = if useQtFromNixpkgs then qt68Packages else qt6Packages;
  python3' = if useQtFromNixpkgs then qt68python312 else python312;

  releases = builtins.fromJSON (builtins.readFile ./releases.json);

  # Helper function to format the package name based on edition and version type
  formatPname = { edition, isDev }: "binaryninja-${edition}" + (if isDev then "-beta" else "");

  patchSharedLibs = lib.optionalString stdenv.hostPlatform.isLinux ''
    # libxml2 soname changes now follow ABI breaks.
    # https://gitlab.gnome.org/GNOME/libxml2/-/issues/751
    # This is of course ultimately good, but we can't recompile binja
    # So let's just force it to use whatever NixOS has. It's Probably Fine™
    # https://github.com/NixOS/nixpkgs/blob/2fb006b87f04c4d3bdf08cfdbc7fab9c13d94a15/pkgs/applications/editors/jetbrains/default.nix#L170-L182
    ls -d \
      $out/opt/*/plugins/lldb/lib/liblldb.so* |
    xargs patchelf \
      --replace-needed libxml2.so.2 libxml2.so
  '';

  # Helper function to check dev version suffix
  isDevVersion = version: lib.hasSuffix "-dev" version;

  # Helper function to create a derivation for a specific version and edition
  mkBinaryNinjaDerivation = {
    version,
    edition,
    hash,
    binaryNinjaSource ? null,
  }:
    let
      isDev = isDevVersion version;
      fileNameSuffix = if isDev then "" else "-stable";
      fileName = "binaryninja_linux_${edition}.${version}${fileNameSuffix}.7z";
      pname = formatPname { inherit edition isDev; };

      defaultSource = requireFile {
        name = fileName;
        inherit hash;
        url = "https://binary.ninja/recover/"; # Placeholder URL
      };

      desktopIcon = fetchurl {
        url = "https://docs.binary.ninja/img/logo.png";
        hash = "sha256-TzGAAefTknnOBj70IHe64D6VwRKqIDpL4+o9kTw0Mn4=";
      };

    in
    stdenv.mkDerivation (finalAttrs: {
      inherit pname version;

      src = if binaryNinjaSource != null then binaryNinjaSource else defaultSource;

      nativeBuildInputs = [
        _7zz
        autoPatchelfHook
        makeWrapper
        copyDesktopItems
        makeSanitizedLauncherHook
        python3'.pkgs.wrapPython # For Python plugins
        qt6Packages'.wrapQtAppsHook # For Qt applications
      ];

      buildInputs = [
        dbus
        fontconfig
        freetype
        glib
        libGL
        libGLU
        libxkbcommon
        libxml2
        wayland
        xorg.libXi
        xorg.libXrender
        xorg.xcbutilimage
        xorg.xcbutilkeysyms
        xorg.xcbutilrenderutil
        xorg.xcbutilwm
        qt6Packages'.qtbase
        qt6Packages'.qtdeclarative
        qt6Packages'.qtwayland
        python3'
        python3'.pkgs.pip
      ] ++ lib.optionals useQtFromNixpkgs [
        python3'.pkgs.pyside6
        python3'.pkgs.shiboken6
      ];

      pythonPath = with python3'.pkgs; [
        pip
      ] ++ lib.optionals useQtFromNixpkgs [
        pyside6
        shiboken6
      ];
      appendRunpaths = [ "${lib.getLib python3'}/lib" ];

      unpackPhase = ''
        runHook preUnpack

        # Create a temporary directory for unpacking
        local tmp_dir
        tmp_dir=$(mktemp -d)

        # Unpack the 7z file into the temporary directory
        7zz x -snld $src -o"$tmp_dir"

        # The 7z file should contain a single directory with the application contents.
        # We verify this and move the contents to the top level of the build directory.
        local dir_path
        dir_path=$(find "$tmp_dir" -maxdepth 1 -mindepth 1 -type d)

        if [ -z "$dir_path" ] || [ "$(echo "$dir_path" | wc -l)" -ne 1 ]; then
          echo "error: The archive must contain exactly one directory."
          exit 1
        fi

        # Move contents from the found directory to the current build directory
        mv "$dir_path"/* .

        # Clean up the temporary directory
        rm -rf "$tmp_dir"

        runHook postUnpack
      '';

      installPhase = ''
        runHook preInstall

        # Create the main installation directory
        mkdir -p $out/opt/${pname}
        # Copy all extracted contents into it
        cp -r . $out/opt/${pname}

        # Clean up redundant shared libraries to reduce closure size and avoid conflicts
        find $out/opt/${pname} \
          -type f \
          -name '*.so.*' \
          -not -name 'libbinaryninjacore.so.*' \
          -not -name 'libbinaryninjaui.so.*' \
          -not -name 'liblldb.so.*' \
          -not -name 'libicu*.so.*' \
          -not -name 'libQt6*.so.*' \
          -not -name 'libshiboken6.abi*.so.*' \
          -not -name 'libpyside6.abi*.so.*' \
          -delete
        # Use Qt6 & PySide6 from nixpkgs
        if [ "${toString useQtFromNixpkgs}" == "1" ]; then
          # Remove Qt6 Libraries
          find $out/opt/${pname} -name 'libicu*.so.*' -delete
          find $out/opt/${pname} -name 'libQt6*.so.*' -delete
          # Clean up Qt plugins
          find $out/opt/${pname}/qt -type f -name '*.so' -delete
          # Clean up Qt Python bindings
          rm -r $out/opt/${pname}/python3/{PySide6,shiboken6}
          find $out/opt/${pname} -name 'libshiboken6.abi*.so.*' -delete
          find $out/opt/${pname} -name 'libpyside6.abi*.so.*' -delete
        fi

        # Create bin directory and wrapper
        mkdir -p $out/bin
        buildPythonPath "$pythonPath"
        makeWrapper $out/opt/${pname}/binaryninja $out/bin/${pname} \
          --prefix PATH : "${lib.makeBinPath [ python3' ]}" \
          --prefix PYTHONPATH : "$program_PYTHONPATH" \
          --prefix LD_LIBRARY_PATH : "$out/opt/${pname}" \
          "''${sanitizedLauncherArgs[@]}" \
          "''${qtWrapperArgs[@]}"

        makeWrapper $out/opt/${pname}/bnpython3 $out/bin/bnpython3

        # Install icon
        mkdir -p $out/share/pixmaps
        install -Dm644 ${desktopIcon} $out/share/pixmaps/binaryninja.png

        runHook postInstall
      '';

      postInstall = ''
        # Remove unknown build-time package references
        rm "$out/opt/${pname}/env-vars"
      '';

      preFixup = ''
        ${patchSharedLibs}
      '';

      dontWrapQtApps = true; # Handled by makeWrapper and qtWrapperArgs
      dontWrapWithSanitizedLauncher = true;  # Handled by makeWrapper and sanitizedLauncherArgs
      sanitizedLaunchers = [ "xdg-open" ];

      desktopItems = [
        (makeDesktopItem {
          name = pname;
          exec = pname;
          icon = "binaryninja";
          desktopName = "Binary Ninja ${lib.toSentenceCase edition}" + (if isDev then " (Dev Channel)" else "");
          mimeTypes = [
            "application/x-binaryninja"
            "x-scheme-handler/binaryninja"
          ];
          comment = "Binary Ninja is an interactive decompiler, disassembler, debugger, and binary analysis platform built by reverse engineers, for reverse engineers";
          categories = [ "Utility" ];
          terminal = false;
          # get WMClass from `qdbus org.kde.KWin /KWin queryWindowInfo | grep -i class`
          startupWMClass = "binaryninja";
        })
      ];

      meta = with lib; {
        changelog = "https://binary.ninja/changelog/#${
          replaceStrings [ "." ] [ "-" ] finalAttrs.version
        }";
        description = "Interactive decompiler, disassembler, debugger";
        homepage = "https://binary.ninja/";
        license = licenses.unfree;
        mainProgram = pname;
        maintainers = with maintainers; [ ];
        platforms = [ "x86_64-linux" ];
        sourceProvenance = with sourceTypes; [ binaryNativeCode ];
      };
    });

  # Generate a list of packages, e.g.:
  # [ { name = "binaryninja-commercial"; value = <derivation>; } ]
  packages = lib.flatten (lib.mapAttrsToList (edition: versions:
    let
      stableVersions = lib.filterAttrs (v: _: !isDevVersion v) versions;
      devVersions = lib.filterAttrs (v: _: isDevVersion v) versions;

      safeLast = list: if list == [] then null else lib.last list;

      # Get the last version of each type to be the default
      latestStableVersion = safeLast (lib.attrNames stableVersions);
      latestDevVersion = safeLast (lib.attrNames devVersions);

      # Create a package for the latest stable version if it exists
      stablePkg = if latestStableVersion != null then {
        name = formatPname { inherit edition; isDev = false; };
        value = (mkBinaryNinjaDerivation {
          version = latestStableVersion;
          hash = stableVersions.${latestStableVersion};
          inherit edition;
        }).overrideAttrs (old: {
          passthru.allVersions = lib.mapAttrs'
            (v: h: lib.nameValuePair v (mkBinaryNinjaDerivation { version = v; hash = h; inherit edition; }))
            stableVersions;
        });
      } else null;

      # Create a package for the latest dev version if it exists
      devPkg = if latestDevVersion != null then {
        name = formatPname { inherit edition; isDev = true; };
        value = (mkBinaryNinjaDerivation {
          version = latestDevVersion;
          hash = devVersions.${latestDevVersion};
          inherit edition;
        }).overrideAttrs (old: {
          passthru.allVersions = lib.mapAttrs'
            (v: h: lib.nameValuePair v (mkBinaryNinjaDerivation { version = v; hash = h; inherit edition; }))
            devVersions;
        });
      } else null;

    in
      # Return a list of the created packages, filtering out nulls
      lib.filter (p: p != null) [ stablePkg devPkg ]
  ) releases);
  # Convert the list of packages into the final attribute set
  packageSet = lib.listToAttrs packages;
in
lib.recurseIntoAttrs packageSet
