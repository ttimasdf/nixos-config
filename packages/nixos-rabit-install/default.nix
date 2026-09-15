# The first-install helper shipped on the installer ISO and usable on any
# host. It wraps scripts/nixos-rabit-install.sh so the install manual can refer
# to a stable command name in PATH.
{ lib
, writeShellApplication
, coreutils
, git
, util-linux
,
}:

writeShellApplication {
  name = "nixos-rabit-install";

  runtimeInputs = [
    coreutils
    git
    util-linux
  ];

  # scripts/nixos-rabit-install.sh is the canonical source. writeShellApplication
  # adds the shebang, `set -o errexit` etc., and runs shellcheck over it.
  text = builtins.readFile ../../scripts/nixos-rabit-install.sh;

  meta = {
    description = "Bootstrap a new host of the KnownRabbit NixOS config as its first generation";
    license = lib.licenses.mit;
    mainProgram = "nixos-rabit-install";
  };
}
