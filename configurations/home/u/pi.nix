{ config, lib, pkgs, isDarwin, ... }:

{
  rabit.home.pi.agents = ''
    # System Guidance

    - NixOS: for missing tools use `nix-shell -p <pkg> --run '<command>'`; never install globally.
    - No `apply_patch`: use `edit` for targeted changes and `write` for new/full-rewrite files.
    - Python: use `uv`, not `pip`; ad-hoc scripts use `uv run --with <deps>` or PEP 723 metadata.
    - JS: use `bun`/`bunx`/`pnpm`; use `npm`/`npx` only when `package-lock.json` exists.
    - Long-running commands: run one foreground command with a timeout sized for the full expected duration; poll and print progress within that invocation. Do not background it or repeatedly relaunch it with short timeouts.
  '';
}