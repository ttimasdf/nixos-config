# The first-install helper shipped on the installer ISO and usable on any
# host. It wraps scripts/install.sh so the install manual can refer to a
# stable command name in PATH.
{ lib
, writeShellApplication
, coreutils
, git
, util-linux
,
}:

writeShellApplication {
  name = "nixos-install-config";

  runtimeInputs = [
    coreutils
    git
    util-linux
  ];

  # scripts/install.sh is the canonical source. writeShellApplication adds the
  # shebang, `set -o errexit` etc., and runs shellcheck over the result.
  text = builtins.readFile ../../scripts/install.sh;

  meta = {
    description = "Bootstrap a new host of the KnownRabbit NixOS config as its first generation";
    license = lib.licenses.mit;
    mainProgram = "nixos-install-config";
  };
}
