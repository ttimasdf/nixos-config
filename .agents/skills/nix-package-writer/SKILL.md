---
name: nix-package-writer
description: Help write new Nix package definitions for this nixos-config repository. Use this skill whenever the user asks to add, package, vendor, build, fix, or update a package under packages/, create a derivation, package an AppImage/deb/Rust/Node/Tauri/binary application, or asks how to make something available as pkgs.<name>. This skill is specifically for new packages; do not use it for Nixpkgs overlays or overriding existing packages.
---

# Nix Package Writer

Use this skill to add or repair package definitions in this repository's `packages/` tree. The repo auto-discovers packages, so the main job is to create a correct package file that matches local conventions and can be built by `nix`.

## Scope

This skill covers new package definitions only:

- `packages/<name>.nix`
- `packages/<name>/default.nix`
- supporting files inside `packages/<name>/`, such as patches, update scripts, icons, or helper scripts

Do not use this skill for overlays, package overrides, or changes under `overlays/`. If the user asks to override an existing Nixpkgs package, use an overlay-specific workflow instead.

## First steps

1. Read `packages/AGENTS.md` and any nearby package examples that match the requested source type.
2. Inspect the upstream project layout before writing phases. Do not guess build commands from the README alone if source files are available.
3. Decide between a single file and a directory package:
   - Use `packages/<name>.nix` for self-contained packages.
   - Use `packages/<name>/default.nix` when you need patches, helper scripts, update scripts, local assets, or multi-file package logic.
4. Keep the package as a direct child of `packages/`. `rabit-lib.forAllNixFiles` does not recurse into nested namespaces, so `packages/foo/bar/default.nix` will not become `pkgs.foo.bar`.

## Repository conventions

Packages are wired into `pkgs.*` automatically by the repo's Nixpkgs overlay module using `rabit-lib.forAllNixFiles "${self}/packages"` and `lib.callPackageWith final fn { }`. Do not edit `flake.nix` or manually register the package.

Write package arguments as callPackage parameters. Follow the surrounding style, but prefer the multi-line attrset style for new packages:

```nix
{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "example";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "owner";
    repo = "example";
    rev = "v${finalAttrs.version}";
    hash = lib.fakeHash;
  };

  meta = {
    description = "Short package description";
    homepage = "https://github.com/owner/example";
    license = lib.licenses.mit;
    maintainers = [ ];
    platforms = lib.platforms.linux;
    mainProgram = "example";
  };
})
```

Use the `finalAttrs` pattern when `stdenv.mkDerivation` or language builders need to refer to `version`, `src`, `pname`, dependency hashes, or passthru values. Avoid `rec` for normal derivations; follow existing builder-specific examples when the idiomatic repo pattern uses `rec`, such as `appimageTools.wrapType2 rec { ... }` for AppImages.

## Source and hash workflow

Use the fetcher that matches the upstream artifact:

- `fetchFromGitHub` for source repositories.
- `fetchurl` for release tarballs, AppImages, `.deb`, `.rpm`, or other binary artifacts.
- `requireFile` for user-supplied proprietary files that cannot be downloaded automatically.

For new or changed hashes, use `lib.fakeHash` first, build once, then replace it with the real hash from the Nix error. This applies to source hashes and ecosystem dependency hashes such as `cargoHash`, `npmDepsHash`, `pnpmDeps.hash`, or vendor hashes.

For multi-platform sources, define a `sources` attrset keyed by platform and select with `stdenv.hostPlatform.system`. Set `meta.platforms = builtins.attrNames passthru.sources` when `passthru.sources` exposes the supported platforms.

## Build pattern selection

Choose the smallest builder that matches upstream:

- C/C++ or generic source: `stdenv.mkDerivation` with explicit phases only when defaults are insufficient.
- Rust crates: `rustPlatform.buildRustPackage`; use `cargoHash` or `cargoLock.lockFile`/`importCargoLock` based on upstream lockfile availability.
- Rust workspaces or Tauri apps: `stdenv.mkDerivation` plus `rustPlatform.cargoSetupHook`, `cargo`, `rustc`, and explicit `cargo build --frozen` if frontend steps must run first.
- Node/pnpm projects: use `pnpm.configHook` and `fetchPnpmDeps` when the repo has a pnpm lockfile.
- AppImage packages: use `appimageTools.extractType2` plus `appimageTools.wrapType2`, install desktop files/icons from extracted contents, and set `meta.sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];`.
- `.deb` binary packages: use `dpkg` in `unpackPhase`; usually pair with `autoPatchelfHook`, wrappers, desktop items, and explicit runtime libraries.
- Setup hooks/helper packages: use `makeSetupHook` or the smallest Nix helper function instead of wrapping it in `stdenv.mkDerivation` unnecessarily.

Distinguish dependency categories carefully:

- `nativeBuildInputs`: tools run during the build, such as `pkg-config`, `makeWrapper`, `autoPatchelfHook`, `copyDesktopItems`, language setup hooks, compilers, `nodejs`, or `pnpm.configHook`.
- `buildInputs`: libraries linked or discovered by the package, such as `openssl`, GTK/WebKit libraries, `zlib`, or system libraries.
- `runtimeDependencies`: runtime libraries/tools needed by wrappers or auto-patchelf when the package is a prebuilt binary.

## Phases and shell snippets

Write explicit phases only when default phases cannot infer the build. Keep hooks intact:

```nix
buildPhase = ''
  runHook preBuild

  make

  runHook postBuild
'';

installPhase = ''
  runHook preInstall

  install -Dm755 example $out/bin/example

  runHook postInstall
'';
```

Use `install -Dm...` for binaries, desktop files, icons, and assets. For wrappers, prefer `makeWrapper`/`makeBinaryWrapper` over ad-hoc shell scripts. Use `substituteInPlace --replace-fail` when patching known text so upstream changes fail loudly.

Nix builds are sandboxed and offline. Skip or patch tests that require network access instead of letting them fail nondeterministically. Explain each skipped test with a short comment.

## Metadata

Every package should include `meta` with at least:

- `description`
- `homepage`
- `license`
- `maintainers = [ ];`

Add when relevant:

- `platforms = lib.platforms.linux;` or a narrower list like `[ "x86_64-linux" ]`.
- `mainProgram` for executable packages.
- `downloadPage` for release-artifact packages.
- `sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];` for prebuilt binaries, AppImages, proprietary archives, or repackaged binary releases.

## Local helper patterns

Use repo-specific helper packages only when they solve the actual packaging problem; do not add them speculatively.

- `makeSanitizedLauncherHook` is useful for prebuilt GUI apps that are known to launch external programs and may leak bundled `LD_LIBRARY_PATH` or `PYTHONPATH`.
- `makeDesktopItemExtended` can help when a generated desktop item needs extra fields beyond the standard helper.

Read the helper package README or implementation before using it.

## Validation

After editing a package, run targeted checks first:

```bash
nix build .#<package-name>
nix develop .#<package-name>
```

Inside the package devshell, use `runPhase <phase>` to debug individual phases. For repo-wide validation, use the existing tasks when appropriate:

```bash
nix fmt
nix flake check
```

If a fake hash was used, build once, replace the hash Nix reports, and build again. Do not report success while `lib.fakeHash` remains in a source or dependency hash unless the user explicitly asked only for a draft.

## Output expectations

When implementing, produce the package files and a concise handoff that includes:

- the new `pkgs.<name>` attribute path
- important packaging choices, especially source type and builder
- any hashes that still need replacement
- exact validation commands run and their results

When advising instead of editing, provide a package skeleton tailored to the upstream project and call out which values the user must supply.
