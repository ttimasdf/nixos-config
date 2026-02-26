# Writing Nix Config

## Write an overlay
All `.nix` files placed in the `overlays/` directory are automatically discovered and applied as Nixpkgs overlays. This is handled by the `modules/nixos/common/nixpkgs-overlays.nix` module.

Here are some common patterns for writing overlays:

### General Package Override Example
This example shows how to modify attributes of an existing package, such as changing its version, source, or adding a post-installation hook.

when writing source hash, use `lib.fakeHash` as the placeholder.

```nix
{ flake, ... }:
final: prev:
{
  my-package-override = prev.my-package.overrideAttrs (oldAttrs: {
    version = "NEW_VERSION"; # Replace with the desired version
    src = prev.fetchFromGitHub {
      owner = "GITHUB_OWNER"; # Replace with the GitHub owner
      repo = "GITHUB_REPO"; # Replace with the GitHub repository name
      rev = "COMMIT_OR_TAG"; # Replace with the desired commit hash or tag
      hash = lib.fakeHash; # Replace with the actual SHA256 hash of the source
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

### Applying Multiple Patches with `rabit-lib.findPatches`
This example demonstrates how to apply a directory of patches using `rabit-lib.findPatches`. This is particularly useful when you have multiple patches that need to be applied to a package, and `rabit-lib` is available as part of your current flake's inputs.

```nix
{ flake, ... }:
final: prev:
let
  inherit (flake.inputs.self) rabit-lib; # Assuming 'rabit-lib' is inherited from the current flake's (self) inputs
in
{
  my-patched-package = prev.some-package.overrideAttrs (oldAttrs: {
    # Apply all .patch files from a directory relative to your overlay file
    patches = (oldAttrs.patches or []) ++ (rabit-lib.findPatches ./patches);
  });
}
```

For more advanced examples, including how to override packages in specific sets (like `kdePackages` or `python3.pkgs`), or how to use pinned Nixpkgs versions, please refer to [`overlays/overlay-template.md`](../../overlays/overlay-template.md).

## Write a new package
All `.nix` files and directories placed in the `packages/` directory are automatically discovered using `rabit-lib.forAllNixFiles "${self}/packages"`. Each `.nix` file or directory containing a `default.nix` becomes a top-level package attribute.

To add a new package:
1.  **Create a package file or directory**: Inside `packages/`, either create a `.nix` file directly (e.g., `packages/my-new-package.nix`) or create a directory with a `default.nix` entry point (e.g., `packages/my-new-package/default.nix`).
2.  **Write the package definition**:
    **Example: Single-file package (`packages/my-new-package.nix`)**
    ```nix
    # packages/my-new-package.nix
    { lib, stdenv, fetchurl }:

    stdenv.mkDerivation {
      pname = "my-new-package";
      version = "1.0.0";

      src = fetchurl {
        url = "https://example.com/my-new-package-1.0.0.tar.gz";
        hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Replace with actual hash
      };
      # use fetchurl/fetchFromGitHub/requireFile etc,
      # add necessary instructions for user
      # to add hash or required files.

      # ... your package logic here ...
    }
    ```
    **Example: Directory package with `default.nix` (`packages/my-new-package/default.nix`)**
    Use a directory when you need extra files (patches, helper scripts, etc.) alongside the package definition.
    ```
    packages/my-new-package/
    ├── default.nix
    ├── my-extra-feature.patch
    └── support-definitions.nix
    ```
    Note: `forAllNixFiles` does NOT recurse into nested namespaces. Every discovered entry becomes a top-level package attribute.

3.  **Using your new package**:
    - A `.nix` file `packages/foo.nix` is accessible as `pkgs.foo`.
    - A directory `packages/foo/default.nix` is accessible as `pkgs.foo`.

    ```nix
    # In configurations/nixos/viscacha/configuration.nix
    environment.systemPackages = with pkgs; [
      my-new-package # From packages/my-new-package.nix or packages/my-new-package/default.nix
    ];
