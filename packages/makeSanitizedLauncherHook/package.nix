{ stdenv, makeSetupHook }:

makeSetupHook {
  name = "make-sanitized-launcher-hook";
  substitutions = {
    shell = stdenv.shell;
  };
} ./make-sanitized-launcher.sh
