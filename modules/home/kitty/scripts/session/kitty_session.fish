complete -c kitty-session -f -n '__fish_use_subcommand' -a 'backup' -d 'Write a session snapshot'
complete -c kitty-session -f -n '__fish_use_subcommand' -a 'restore' -d 'Select and restore a session snapshot'
complete -c kitty-session -f -n '__fish_use_subcommand' -a 'list' -d 'List saved session snapshots'

complete -c kitty-session -f -n '__fish_seen_subcommand_from restore' -a '(kitty-session __complete restore (commandline -ct) 2>/dev/null)'
complete -c kitty-session -f -n '__fish_seen_subcommand_from backup' -l force -d 'Replace an existing snapshot'
complete -c kitty-session -f -n '__fish_seen_subcommand_from backup' -l best-effort -d 'Allow inaccessible Kitty servers'
