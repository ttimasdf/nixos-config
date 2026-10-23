#!/usr/bin/env bash
# clean-old.sh — remove entries in a directory created >= <age> ago
#
# Usage:   clean-old.sh [--delete] [--size-dirs] [--dir PATH] <N[s|m|h|d|w]>
#          e.g. clean-old.sh 2d            # preview: what would be removed
#               clean-old.sh 12h            # preview, 12+ hours old
#               clean-old.sh --delete 2d    # actually remove
# Flags:
#   --delete      actually remove entries (default: dry-run preview)
#   --size-dirs   also walk directories for their sizes (slow on big trees)
#   --dir PATH    target directory (default: /tmp)
#
# Notes:
# - Non-recursive: only top-level entries of the target directory.
# - Uses real birth time (crtime) when the filesystem provides it,
#   falling back to ctime otherwise.
# - Fast: one batched stat call for all entries; no du traversal and no
#   per-entry subprocesses.
# - Skips live system/session infrastructure (systemd-private-*, X11
#   sockets, tmux sockets, ...) and the script itself.

set -euo pipefail

usage() {
    cat >&2 <<EOF
usage: ${0##*/} [options] <N[s|m|h|d|w]>
  e.g. ${0##*/} 2d                 preview entries >= 2 days old in /tmp
       ${0##*/} --delete 2d        actually remove them
       ${0##*/} --dir /var/tmp 1w  preview elsewhere; combine with --delete
  --delete      actually remove entries (default: dry-run preview)
  --size-dirs   also walk directories for their sizes (slow on big trees)
  --dir PATH    target directory (default: /tmp)
EOF
    exit 1
}

dry=1
size_dirs=0
dir=/tmp
age=
delete_seen=0
dryrun_seen=0
while [ $# -gt 0 ]; do
    case $1 in
        -h|--help)    usage ;;
        --delete)    delete_seen=1; dry=0; shift ;;
        --dry-run)   dryrun_seen=1; dry=1; shift ;;
        --size-dirs) size_dirs=1; shift ;;
        --dir)       [ $# -ge 2 ] || { echo "--dir requires a path" >&2; usage; }
                     dir=$2; shift 2 ;;
        --dir=*)     dir=${1#--dir=}; shift ;;
        --*)         echo "unknown option: $1" >&2; usage ;;
        *)           [ -z "$age" ] || usage; age=$1; shift ;;
    esac
done
if [ "$delete_seen" = 1 ] && [ "$dryrun_seen" = 1 ]; then
    echo "error: --delete and --dry-run are mutually exclusive" >&2
    usage
fi
[ -n "$age" ] || usage
[[ $age =~ ^([0-9]+)([smhdw])$ ]] || usage
n=${BASH_REMATCH[1]} unit=${BASH_REMATCH[2]}
case $unit in
    s) secs=$((n)) ;;
    m) secs=$((n * 60)) ;;
    h) secs=$((n * 3600)) ;;
    d) secs=$((n * 86400)) ;;
    w) secs=$((n * 604800)) ;;
esac

[ -d "$dir" ] || { echo "error: not a directory: $dir" >&2; exit 1; }
dir=$(readlink -f -- "$dir") || { echo "error: cannot resolve: $dir" >&2; exit 1; }
[ "$dir" != "/" ] || { echo "error: refusing to operate on /" >&2; exit 1; }

cutoff=$(( $(date +%s) - secs ))
self=$(readlink -f -- "$0")

# Never touch live session/system infrastructure commonly found in /tmp
protected_re='^systemd-private-|^snap\.|^\.X11-unix$|^\.ICE-unix$|^\.font-unix$|^\.XIM-unix$|^\.Test-unix$|^\.X[0-9]+-lock$|^\.X[0-9]+$|^tmux-[0-9]+$|^\.virtofs-'

removed=0
freed_kb=0

shopt -s nullglob dotglob
entries=("$dir"/*)
if [ ${#entries[@]} -eq 0 ]; then
    echo "nothing found in $dir"
    exit 0
fi

# Single batched stat pass, one record per line: birth|ctime|size|path
# (paths containing newlines/pipes are pathological; the -e guard below
# makes any garbled record a no-op instead of a wrong delete)
while IFS='|' read -r b cz sz f; do
    [ -e "$f" ] || continue
    base=${f##*/}
    [ "$f" -ef "$self" ] && continue
    [[ $base =~ $protected_re ]] && continue

    if [ -z "$b" ] || [ "$b" = "-" ] || [ "$b" = "0" ]; then b=$cz; fi # fallback: ctime
    [[ $b =~ ^[0-9]+$ ]] || continue
    [ "$b" -lt "$cutoff" ] || continue

    printf -v when '%(%F %T)T' "$b" 2>/dev/null || when=$b

    if [ -d "$f" ]; then
        kb=0; size="directory"
        if [ "$size_dirs" = "1" ]; then
            kb=$(du -sk -- "$f" 2>/dev/null | cut -f1) || kb=0
            [ "$kb" -gt 0 ] && size="directory ($kb KB)"
        fi
    else
        kb=$(( (sz + 1023) / 1024 ))
        size="$kb KB"
    fi

    if [ "$dry" = 1 ]; then
        printf 'would remove: %-56s %22s  (created %s)\n' "$base" "$size" "$when"
    else
        rm -rf -- "$f"
        printf 'removed:      %-56s %22s  (created %s)\n' "$base" "$size" "$when"
    fi
    removed=$((removed + 1))
    freed_kb=$((freed_kb + kb))
done < <(stat -c '%W|%Z|%s|%n' -- "${entries[@]}" 2>/dev/null)

if [ "$removed" -eq 0 ]; then
    echo "nothing created >= $age ago found in $dir"
else
    action="removed"; [ "$dry" = 1 ] && action="would remove"
    note=""; [ "$size_dirs" != "1" ] && note=" (file sizes only)"
    echo "$action $removed entries ($((freed_kb / 1024)) MB$note) in $dir [threshold: >= $age ago]"
    [ "$dry" = 1 ] && echo "dry run — nothing deleted; pass --delete to remove"
fi
