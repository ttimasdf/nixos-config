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
    if [ "$target_commit" = "47cb985265b393c057033262f45065f115ea0bba" ]; then
        echo "skip older commits..."
        exit 0
    fi
    version_hint=$(git show "${target_commit}:$FILE")
    commit_date=$(git show -s --format=%cd --date=format:'%Y.%m.%d' "$target_commit")

    # Check if tag already exists on this commit (skip creation)
    existing_tags=$(git tag --points-at "$target_commit")
    if [ "$DELETE" != true ] && [[ -n "$existing_tags" ]]; then
        echo "Skipping commit $target_commit - already has tag(s): $existing_tags"
        continue
    fi

    if [ "$DELETE" = true ]; then
        tags=$existing_tags
        for tag in $tags; do
            if [[ "$tag" =~ ^v[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]; then
                if [ "$DRY_RUN" = true ]; then
                    echo "[DRY RUN] Would delete tag '$tag' on commit $target_commit"
                else
                    git tag -d "$tag"
                    echo "Deleted tag $tag on $target_commit"
                fi
            fi
        done
        continue
    fi

    counter=1
    tag_name=$(printf "v%s.%02d" "$commit_date" "$counter")

    while git rev-parse "$tag_name" >/dev/null 2>&1; do
        counter=$((counter + 1))
        tag_name=$(printf "v%s.%02d" "$commit_date" "$counter")
    done
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would create tag '$tag_name' on commit $target_commit with message: $version_hint"
    else

        git tag "$tag_name" "$target_commit" -m "$version_hint"
        echo "Created tag $tag_name on $target_commit"
    fi
done
