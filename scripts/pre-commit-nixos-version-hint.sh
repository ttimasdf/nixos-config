#!/bin/sh

# Check if there are any .nix files in the staged changes
if ! git diff --cached --name-only | grep -qE '\.nix$'; then
  # No .nix files staged for commit. Skipping nixos-version-hint.txt check.
  exit 0
fi

FILE_NAME="nixos-version-hint.txt"
FILE_NAME_SKIP=".nixos-version-hint-skip"

if [ -f "$FILE_NAME_SKIP" ]; then
  # $FILE_NAME_SKIP exists. skip version hint check
  exit 0
fi

# Get current value from the work tree
work_tree_value=$(cat "$FILE_NAME" 2>/dev/null || echo "")
echo -n "Current value in work tree: '$work_tree_value' "

# Check if $FILE_NAME is staged for commit
if git diff --cached --name-only | grep -q "$FILE_NAME"; then
  echo "$FILE_NAME is staged for commit. Proceeding with commit."
else
  echo -n "Error: $FILE_NAME was not updated. Please update it before committing. "

  # Check if the file has been modified in the work tree compared to HEAD
  if ! git diff --quiet "$FILE_NAME"; then
    # If modified, get and display the last committed value
    committed_value=$(git show HEAD:"$FILE_NAME" 2>/dev/null || echo "")
    echo -n ". Last committed value: '$committed_value'"
  fi
  echo ""
  exit 1
fi
