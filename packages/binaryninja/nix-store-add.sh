#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [FILE...]

Add Binary Ninja files to Nix store and generate Nix hash.

Arguments:
  FILE...     Optional paths to Binary Ninja files (e.g., binaryninja_linux_stable_commercial.5.1.8005.7z)
              If no files are specified, automatically finds all binaryninja_linux*.7z files in current and subdirectories.

Options:
  -h, --help  Show this help message and exit

Examples:
  $0                                    # Process all binaryninja_linux*.7z files found
  $0 binaryninja_linux_stable_commercial.5.1.8005.7z
  $0 file1.7z file2.7z file3.7z
EOF
}

outfile=$(mktemp)

# Parse command line arguments
files=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            files+=("$1")
            shift
            ;;
    esac
done

# If no file arguments provided, find all binaryninja_linux*.7z files
if [[ ${#files[@]} -eq 0 ]]; then
    echo "No files specified, searching for binaryninja_linux*.7z files..."
    mapfile -t files < <(find . -name "binaryninja_linux*.7z" -type f 2>/dev/null | sort)

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "Error: No binaryninja_linux*.7z files found in current or subdirectories" >&2
        exit 1
    fi

    echo "Found ${#files[@]} files:"
    printf '  %s\n' "${files[@]}"
    echo
fi

# Process each file
for file in "${files[@]}"; do
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo "Error: File '$file' does not exist" >&2
        exit 1
    fi

    echo "Processing: $file"
    fpath="$(realpath "$file")"
    hash=$(nix-hash --type sha256 --sri --flat "$fpath")
    echo "SHA256 hash: $hash"
    nix-prefetch-url --type sha256 --print-path "file://$fpath" "$hash" | tee -a "$outfile"
    echo "---"
done

grep /nix/store "$outfile" > nix-paths.txt
rm "$outfile"

