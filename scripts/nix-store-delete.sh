#!/usr/bin/env bash

set -ex

while read line; do
    nix-store --query --referers $line || nix-store --delete $line
done < nix-paths.txt
