{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:

{
  rabit.home.pi.agents = ''
    # System Guidance

    - NixOS: for missing tools use `nix-shell -p <pkg> --run '<command>'`; never install globally.
    - No `apply_patch`: use `edit` for targeted changes and `write` for new/full-rewrite files.
    - Python: use `uv`, not `pip`; ad-hoc scripts use `uv run --with <deps>` or PEP 723 metadata.
    - JS: use `bun`/`bunx`/`pnpm`; use `npm`/`npx` only when `package-lock.json` exists.
    - Long-running commands: run one foreground command with a timeout sized for the full expected duration; poll and print progress within that invocation. Do not background it or repeatedly relaunch it with short timeouts.
  '';

  programs.zsh.completionInit = ''
    fpath=("$HOME/.zfunc" $fpath)
    if [[ -r "$HOME/.zfunc/_pi" ]]; then
      pi_completion_version="$(sed -n 's/^export PI_COMPLETION_VERSION="\([^"]*\)"$/\1/p' "$HOME/.zfunc/_pi")"
      if [[ -n "$pi_completion_version" ]]; then
        export PI_COMPLETION_VERSION="$pi_completion_version"
      fi
      unset pi_completion_version
    fi
    autoload -U compinit && compinit
  '';
  programs.bash.initExtra = ''
    if command -v pi-completion >/dev/null 2>&1; then
      source <(pi-completion bash)
    fi
  '';
}
