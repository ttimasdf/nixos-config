# Make Sanitized Launcher Hook

This hook provides a way to create sanitized launchers for applications. These launchers are designed to run external applications in a clean environment, preventing issues with environment variables like `LD_LIBRARY_PATH` and `PYTHONPATH`.

This is particularly useful for pre-built applications that bundle their own libraries (e.g., Qt, GTK). When such an application tries to launch an external program (like a web browser), the bundled libraries can conflict with the system libraries, causing the external program to fail. The sanitized launchers created by this hook ensure that external applications are executed in a clean environment, free from potentially conflicting libraries.

It also provides an automatic wrapping mechanism for all ELF binaries in `$out/bin`, prepending the sanitized launcher directory to their `PATH`.

## Usage

To use this hook, add it to the `nativeBuildInputs` of your derivation.

```nix
{ pkgs, ... }:

pkgs.stdenv.mkDerivation {
  # ...
  nativeBuildInputs = [ pkgs.makeSanitizedLauncherHook ];
  # ...
}
```

### `sanitizedLaunchers`

You must define a list of launchers to be created by setting the `sanitizedLaunchers` bash array in your derivation. If this variable is not set, the build will fail.

```nix
{ pkgs, ... }:

pkgs.stdenv.mkDerivation {
  # ...
  nativeBuildInputs = [ pkgs.makeSanitizedLauncherHook ];

  # Create launchers for firefox and google-chrome
  sanitizedLaunchers = [ "firefox" "google-chrome" ];

  # ...
}
```

This will create sanitized launchers at `$out/libexec/firefox` and `$out/libexec/google-chrome`.

### Automatic Wrapping

The hook will automatically wrap all ELF binaries in `$out/bin`, which prepends the sanitized launcher directory (`$out/libexec`) to their `PATH`. This allows the binaries to find and use the sanitized launchers.

You can disable this behavior by setting `dontWrapWithSanitizedLauncher`:

```nix
{ pkgs, ... }:

pkgs.stdenv.mkDerivation {
  # ...
  nativeBuildInputs = [ pkgs.makeSanitizedLauncherHook ];
  dontWrapWithSanitizedLauncher = true;
  # ...
}
```

### `sanitizedLauncherArgs`

For manual wrapping with `makeWrapper`, the hook provides a `sanitizedLauncherArgs` bash array. This array contains the necessary arguments to prepend the sanitized launcher directory (`$out/libexec`) to the `PATH`.

```nix
{ pkgs, ... }:

pkgs.stdenv.mkDerivation {
  # ...
  nativeBuildInputs = [ pkgs.makeWrapper pkgs.makeSanitizedLauncherHook ];
  sanitizedLaunchers = [ "xdg-open" ];

  installPhase = ''
    # ...
    makeWrapper $out/bin/my-app $out/bin/my-app-wrapped \
      "''${sanitizedLauncherArgs[@]}" \
      --set SOME_VAR "some_value"
    # ...
  '';
  # ...
}
