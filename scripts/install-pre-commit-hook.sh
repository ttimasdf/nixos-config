#!/bin/sh

if [ ! -d .git ]; then
  echo "Run this script from project directory"
  exit 1
fi

# Create .git/hooks directory if it doesn't exist
mkdir -p .git/hooks
cd .git/hooks

HOOK_SOURCE_PATH="../../scripts/pre-commit-nixos-version-hint.sh"
HOOK_TARGET_PATH="pre-commit"

if [ ! -f "$HOOK_SOURCE_PATH" ]; then
  echo "Error: Hook source file not found at $HOOK_SOURCE_PATH"
  exit 1
fi

# Copy the hook script
ln -sf "$HOOK_SOURCE_PATH" "$HOOK_TARGET_PATH"

# Make the hook executable
chmod +x "$HOOK_TARGET_PATH"

echo "Pre-commit hook '$HOOK_SOURCE_PATH' installed to '$HOOK_TARGET_PATH' and made executable."
