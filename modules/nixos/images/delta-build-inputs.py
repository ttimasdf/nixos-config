#!/usr/bin/env python3
"""Work out which build-time inputs the ISO has to carry on top of the host's
own runtime closure.

`nixos-install` regenerates `hardware-configuration.nix` on the target, so the
NixOS system derivations derived from it (`etc`, the systemd units, `activate`,
the initrd, the toplevel and its specialisations) are new derivations that have
to be rebuilt. The ISO preloads the host's runtime closure and `pkgs.stdenv`,
which covers the packages those derivations reference and the compiler, but not
every build-time input: stdenv's builder scripts, `lndir`, jq's `dev` output and
friends are not reachable from any *runtime* closure, and `stdenv`'s output does
not carry them either.

So walk the generated derivations' direct inputs and emit every output the ISO
does not already carry. Carrying an output is enough to satisfy Nix, so the walk
does not descend past the inputs it decides to carry; input drvs whose outputs
are all present are skipped, because Nix will neither build them nor look at
their inputs.

A derivation's ATerm lists inputs and outputs but not the *ranges* of its input
derivations, so over-approximating costs ISO size -- hence this parse of the
`Derive(...)` lists rather than a closure walk over every output.

argv: <the store paths the ISO already carries> <generated derivations>
"""

import os
import re
import sys

OUTPUT_RE = re.compile(r'\("([^"]+)","([^"]*)"')
DRV_RE = re.compile(r'"(/nix/store/[^"]+\.drv)"')
SRC_RE = re.compile(r'"(/nix/store/[^"]+)"')


def parse(path):
    """-> ({output name: path}, {input drv}, {input src}) for a .drv file."""
    with open(path) as handle:
        content = handle.read()

    # Derive([outputs],[inputDrvs],[inputSrcs],platform,builder,args,env)
    outputs, input_drvs, input_srcs = content.split("],[", 2)

    out = dict(OUTPUT_RE.findall(outputs))
    drvs = set(DRV_RE.findall(input_drvs))
    # Only the first list of the remainder: the builder, args and env that
    # follow mention plenty of store paths that are not input sources.
    srcs = set(SRC_RE.findall(input_srcs.split("]", 1)[0]))
    return out, drvs, srcs


def main():
    packed_file, roots_file = sys.argv[1:3]

    carried = set(open(packed_file).read().split())
    # passAsFile joins the list with spaces.
    generated = open(roots_file).read().split()

    needed = {}

    def want(path, why):
        if path and path not in carried:
            needed.setdefault(path, why)

    for root in generated:
        _, input_drvs, input_srcs = parse(root)

        # The generated derivations themselves are rebuilt on the target, so
        # the generic builder machinery and any patch they are built from has
        # to be there.
        for src in sorted(input_srcs):
            want(src, f"{os.path.basename(root)} (input source)")

        for drv in sorted(input_drvs):
            try:
                outputs, _, _ = parse(drv)
            except OSError:
                continue  # not reachable in this build; nothing we can carry
            if not outputs or all(path in carried for path in outputs.values()):
                continue
            for name, path in sorted(outputs.items()):
                want(path, f"{os.path.basename(drv)} [{name}]")

    for path in sorted(needed):
        print(path)

    total = len(needed)
    sys.stdout.flush()
    print(f"iso-delta-build-inputs: {total} path(s)", file=sys.stderr)
    for path, why in sorted(needed.items()):
        print(f"  {os.path.basename(path):<64} # {why}", file=sys.stderr)


if __name__ == "__main__":
    main()
