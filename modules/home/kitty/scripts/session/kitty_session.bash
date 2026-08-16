# Bash completion for kitty-session.
_kitty_session() {
  local current command snapshot
  current="${COMP_WORDS[COMP_CWORD]}"
  command="${COMP_WORDS[1]}"
  COMPREPLY=()

  if (( COMP_CWORD == 1 )); then
    COMPREPLY=( $(compgen -W "backup restore list" -- "$current") )
    return
  fi

  case "$command" in
    restore)
      if (( COMP_CWORD == 2 )); then
        while IFS= read -r snapshot; do
          COMPREPLY+=("$snapshot")
        done < <(kitty-session __complete restore "$current" 2>/dev/null)
        compopt -o filenames
      fi
      ;;
    backup)
      if (( COMP_CWORD == 2 )); then
        COMPREPLY=( $(compgen -W "--force --best-effort" -- "$current") )
      fi
      ;;
  esac
}

complete -F _kitty_session kitty-session
