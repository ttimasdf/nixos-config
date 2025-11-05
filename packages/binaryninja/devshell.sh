#!/usr/bin/env bash

# Create a new tmux session named 'binaryninja-dev' if it doesn't exist
tmux has-session -t binaryninja-dev 2>/dev/null

if [ $? != 0 ]; then
  tmux new-session -s binaryninja-dev -d -n "build"

  # Send commands to the first pane (build shell)
  tmux send-keys -t binaryninja-dev:build 'nix develop .#binaryninja-commercial-dev' C-m
  tmux send-keys -t binaryninja-dev:build '[ $? -eq 0 ] && mkdir -p result/{output,unpack} && pushd result/unpack && export out=$(realpath ../output)' C-m

  # Create a new pane for the run shell, split vertically
  tmux split-window -v -t binaryninja-dev:build
  tmux send-keys -t binaryninja-dev:build.2 "nix-shell ." C-m
  tmux send-keys -t binaryninja-dev:build.2 "mkdir -p result/{output,unpack} && pushd result/output" C-m
fi

# Attach to the tmux session
tmux attach-session -t binaryninja-dev
