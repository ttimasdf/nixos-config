# shellcheck shell=bash

declare -a sanitizedLauncherArgs=()
declare -a sanitizedLaunchers=(${sanitizedLaunchers-})


createSanitizedLauncherHook() {
    echo "sanitizedLaunchers=${sanitizedLaunchers[*]:-}"
    if [ -z "${sanitizedLaunchers[*]:-}" ]; then
        echo "FAIL: sanitizedLaunchers is empty, please specify a list of launchers to sanitize."
        exit 1
    fi

    mkdir -p "$out/libexec"
    cat <<'HEREDOC' > "$out/libexec/.launcher"
#!@shell@
cmd="$(basename "$0")"
# Remove libexec from path
export PATH=$(perl -e 'print join ":", grep { !/libexec/ } split /:/, $ENV{PATH}')
# Remove env variables
unset LD_LIBRARY_PATH PYTHONPATH
if [ "$cmd" = ".launcher" ]; then
    echo "This is a generic launcher for external applications"
    exit -1
fi
exec "$cmd" "$@"
HEREDOC
    chmod +x "$out/libexec/.launcher"
    for launcher in "${sanitizedLaunchers[@]}"; do
        echo "Creating sanitized launchers $out/libexec/$launcher"
        ln -sfv .launcher "$out/libexec/$launcher"
    done

    sanitizedLauncherArgs+=("--prefix" "PATH" ":" "$out/libexec")
    echo "sanitizedLauncherArgs=${sanitizedLauncherArgs[*]:-}"
}

wrapWithSanitizedLauncherHook() {
    [ -z "${dontWrapWithSanitizedLauncher-}" ] || return 0
    [ -z "''${sanitizedLauncherArgs[*]:-}" ] && return 0
    [ -d "$out/bin" ] || return 0

    for f in "$out"/bin/*; do
        # skip non-files and symlinks
        [ -f "$f" ] || continue
        [ -L "$f" ] && continue
        isELF "$f" || continue
        # Do not wrap launchers
        [ "$(realpath "$f")" = "$(realpath "$out/libexec/.launcher")" ] && continue

        # makeWrapper <source> <dest> --args
        # In our case, this will be an in-place wrap
        local wrapped="$f.sanitized-launcher-wrapped"
        mv "$f" "$wrapped"
        makeWrapper "$wrapped" "$f" "''${sanitizedLauncherArgs[@]}"
    done
}

preInstallHooks+=(createSanitizedLauncherHook)
fixupOutputHooks+=(wrapWithSanitizedLauncherHook)
