# Nixpkgs Overlay Examples

This document provides examples of how to create and use Nixpkgs overlays. Overlays allow you to extend or modify the `nixpkgs` package set, enabling custom packages, overrides, and specific version pinning.

## Basic Overlay Structure

The fundamental structure of a Nixpkgs overlay.

```nix
{ flake, lib, ... }:
# This overlay provides custom packages and overrides for Nixpkgs.
# It allows you to introduce new packages, modify existing ones, or pin specific versions of packages.
final: prev:
let
  # Define any local variables, functions, or package imports here.
in
{
  # Define your package overrides and new packages here.
  # Each attribute in this set will be merged into the final Nixpkgs set.
}
```

## Using Pinned Nixpkgs Versions

Examples of how to incorporate specific Nixpkgs versions into your overlay, either from a commit hash or a flake input.

### Pinning Nixpkgs from a Commit Hash

This is useful for ensuring reproducibility or accessing newer/older packages not yet in your main Nixpkgs.

```nix
{ flake, lib, ... }:
final: prev:
let
  pkgs-pinned-commit = import (prev.fetchTarball {
    name = "nixpkgs-pinned-commit";
    url = "https://github.com/NixOS/nixpkgs/archive/COMMIT_HASH.tar.gz"; # Replace COMMIT_HASH with the desired commit
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Replace with the actual SHA256 hash
  }) {
    system = prev.system;
    config.allowUnfree = true; # Set to true to allow unfree packages
  };
in
{
  # You can now use 'pkgs-pinned-commit' to access packages from this pinned version.
}
```

### Using a Pinned Nixpkgs Version from a Flake Input

This assumes you have a `nixpkgs-stable` input defined in your `flake.nix`.

```nix
{ flake, lib, ... }:
final: prev:
let
  nixpkgs-from-flake-input = import flake.inputs.nixpkgs-stable {
    system = prev.system;
    config.allowUnfree = true; # Set to true to allow unfree packages
  };
in
{
  # You can now use 'nixpkgs-from-flake-input' to access packages from this flake input.
}
```

## Overriding Existing Packages

Examples of modifying attributes of an existing package. This can be used to change versions, sources, build inputs, or add post-installation hooks.

### General Package Override Example

```nix
{ flake, lib, ... }:
final: prev:
let
  # Assuming pkgs-pinned-commit or nixpkgs-from-flake-input is defined as above
  # For simplicity, using 'prev' for demonstration.
in
{
  my-package-override = prev.my-package.overrideAttrs (oldAttrs: {
    version = "NEW_VERSION"; # Replace with the desired version
    src = prev.fetchFromGitHub {
      owner = "GITHUB_OWNER"; # Replace with the GitHub owner
      repo = "GITHUB_REPO"; # Replace with the GitHub repository name
      rev = "COMMIT_OR_TAG"; # Replace with the desired commit hash or tag
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Replace with the actual SHA256 hash of the source
    };

    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
    # Example post-installation hook: Wrap executables with environment variables
    postFixup = ''
      for prog in $out/bin/executable1 $out/bin/executable2; do
        if [ -f "$prog" ]; then
          wrapProgram "$prog" \
            --set ENV_VAR1 "VALUE1" \
            --set ENV_VAR2 "VALUE2"
        fi
      done
    '';
  });
}
```

## Creating New Packages

### Creating a New Package Based on an Existing One

This example demonstrates adding a patch and a new build input to an existing package.

```nix
{ flake, lib, ... }:
final: prev:
{
  my-custom-7zip = prev._7zz-rar.overrideAttrs (oldAttrs: {
    pname = oldAttrs.pname + "-custom-suffix"; # Append a suffix to the package name

    # Add a new build input
    buildInputs = (oldAttrs.buildInputs or []) ++ [
      prev.some-new-dependency
    ];

    # Add a patch from a URL
    patches = (oldAttrs.patches or []) ++ [
      (prev.fetchpatch {
        url = "URL_TO_PATCH_FILE"; # Replace with the URL of your patch file
        hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Replace with the actual SHA256 hash of the patch
      })
    ];
  });
}
```

## Overriding Packages in Specific Sets

### Overriding Packages within a Specific Package Set (e.g., `kdePackages`)

```nix
{ flake, lib, ... }:
final: prev:
{
  kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
    my-kde-app = kprev.my-kde-app.overrideAttrs (oldAttrs: {
      buildInputs = oldAttrs.buildInputs ++ [
        kprev.some-kde-dependency
        kprev.another-dependency
      ];
    });
  });
}
```

### Overriding a Python Package within a Specific Python Interpreter

This is useful for customizing Python packages or their dependencies.
To test: `nix-shell -p python3.pkgs.my-python-package`

```nix
{ flake, lib, ... }:
final: prev:
{
  python3 = prev.python3.override {
    # Note: 'pyfinal' and 'pyprev' here refer to the Python package set's final and previous states.
    packageOverrides = pyfinal: pyprev:
      let
        my-python-package-override = pyprev.my-python-package.overrideAttrs (oldAttrs:
        let
          # Define a list of required Qt packages for a PySide6-based application
          qtPackages = with pyprev.qt6; [
            pyprev.ninja
            pyprev.packaging
            pyprev.setuptools
            qtbase
            # Add other optional Qt modules as needed, e.g., qtdeclarative, qtwayland
          ];
          # Create a symlink farm for Qt packages if needed for specific build systems
          linkedQtPackages = prev.symlinkJoin {
            name = "linked-qt-packages";
            paths = qtPackages;
          };
        in
        {
          buildInputs = (
            if prev.stdenv.hostPlatform.isLinux then
              # Linux-specific build inputs
              qtPackages # Add other Linux-specific dependencies here
            else
              # macOS-specific build inputs
              pyprev.qt6.darwinVersionInputs
              ++ [
                linkedQtPackages
                prev.some-macos-dependency # Example: prev.cups for printing on macOS
              ]
          );
          # Add other package-specific overrides here
        });
      in
      {
        # Expose the overridden package
        my-python-package = my-python-package-override;
      };
  };
}
```

## Complete Examples of Package Overlays 

### WPS Office CN Fcitx Input Method Fixup

This overlay provides a fix for `wpsoffice-cn` to work correctly with the Fcitx input method, by wrapping its executables with the necessary environment variables.

```nix
{ flake, lib, ... }:

final: prev:
let
  nixpkgs-stable = import flake.inputs.nixpkgs-stable {
    system = prev.system;
    config.allowUnfree = true;
  };
in
{
  # Fix wpsoffice-cn with fcitx input method
  # workaround: https://wszqkzqk.github.io/2024/03/09/WPS-Fcitx5/
  # package version: 12.1.0.17900 from nixos-25.05 https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/wp/wpsoffice-cn/package.nix
  # installPhase: https://github.com/NixOS/nixpkgs/blob/e643668fd71b949c53f8626614b21ff71a07379d/pkgs/by-name/wp/wpsoffice-cn/package.nix#L108-L127
  wpsoffice-cn-fixup = nixpkgs-stable.wpsoffice-cn.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
    postFixup = ''
      # Wrap WPS Office executables with fcitx environment variables
      for prog in $out/bin/wps $out/bin/wpp $out/bin/et $out/bin/wpspdf; do
        if [ -f "$prog" ]; then
          wrapProgram "$prog" \
            --set GTK_IM_MODULE fcitx \
            --set QT_IM_MODULE fcitx \
            --set XMODIFIERS "@im=fcitx"
        fi
      done
    '';
  });
}
```
