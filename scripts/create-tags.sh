#!/usr/bin/env bash

set -e

FILE="nixos-version-hint.txt"
DRY_RUN=false
declare -A DRY_RUN_COUNTERS

DELETE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; echo "Running in dry-run mode..." ;;
        --delete) DELETE=true; echo "Running in delete mode..." ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

git log --pretty=format:"%H" "$FILE" | while read -r commit_hash; do
    if [[ -z "$commit_hash" ]]; then
        continue
    fi

    target_commit=$(git rev-parse "${commit_hash}^")
    version_hint=$(git show "${target_commit}:$FILE")
    commit_date=$(git show -s --format=%cd --date=format:'%Y.%m.%d' "$target_commit")

    if [ "$DELETE" = true ]; then
        tags=$(git tag --points-at "$target_commit")
        for tag in $tags; do
            if [[ "$tag" =~ ^v[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]; then
                if [ "$DRY_RUN" = true ]; then
                    echo "[DRY RUN] Would delete tag '$tag' on commit $target_commit"
                else
                    git tag -d "$tag"
                    echo "Deleted tag $tag on $target_commit"
                fi
                # if [ "$tag" = "v2026.01.16.6" ]; then echo "skip older commits"; exit 0; fi
            fi
        done
        continue
    fi

    counter=1
    tag_name=$(printf "v%s.%02d" "$commit_date" "$counter")

    if [ "$DRY_RUN" = true ]; then
        if [[ -n "${DRY_RUN_COUNTERS[$commit_date]}" ]]; then
            counter=$((${DRY_RUN_COUNTERS[$commit_date]} + 1))
        else
            while git rev-parse "v${commit_date}.${counter}" >/dev/null 2>&1; do
                counter=$((counter + 1))
            done
        fi

        DRY_RUN_COUNTERS[$commit_date]=$counter
        tag_name=$(printf "v%s.%02d" "$commit_date" "$counter")

        echo "[DRY RUN] Would create tag '$tag_name' on commit $target_commit with message:"
        echo "$version_hint"
        echo "---------------------------------------------------"
    else
        while git rev-parse "$tag_name" >/dev/null 2>&1; do
            counter=$((counter + 1))
            tag_name=$(printf "v%s.%02d" "$commit_date" "$counter")
        done

        git tag -a "$tag_name" "$target_commit" -m "$version_hint"
        echo "Created tag $tag_name on $target_commit"
    fi
    if [ "$tag_name" = "v2026.01.16.06" ]; then echo "skip older commits"; exit 0; fi
done
