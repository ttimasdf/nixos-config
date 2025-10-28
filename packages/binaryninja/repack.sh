#!/usr/bin/env bash

set -euo pipefail

# Ensure 7z is installed
if ! command -v 7z &> /dev/null; then
    echo "7z command not found. Please install p7zip."
    exit 1
fi

# Determine which files to process
files_to_process=()
if [[ "$#" -gt 0 ]]; then
    # If arguments are provided, use them as the files to process
    for arg in "$@"; do
        if [[ -f "$arg" && "$arg" == bn-*.zip ]]; then
            files_to_process+=("$arg")
        else
            echo "Skipping invalid file argument: $arg (must be an existing .zip file matching 'bn-*.zip')"
        fi
    done
    if [[ ${#files_to_process[@]} -eq 0 ]]; then
        echo "No valid zip files provided as arguments."
        exit 1
    fi
else
    # If no arguments, iterate over all zip files in the current directory
    mapfile -t files_to_process < <(find . -maxdepth 1 -type f -name 'bn-*.zip' -print0 | xargs -0)
    if [[ ${#files_to_process[@]} -eq 0 ]]; then
        echo "No zip files found matching 'bn-*.zip' in the current directory."
        exit 0
    fi
fi

for zip_file in "${files_to_process[@]}"; do
    echo "Processing $zip_file..."

    # 1. Recognize edition and version from file name
    # New examples:
    # bn-dev-5.2.8482-dev commercial-linux.zip
    # bn-release-5.1.8104 commercial-linux.zip
    filename=$(basename -- "$zip_file")
    filename_no_ext="${filename%.zip}"

    # Extract version/edition part and OS from filename
    # New examples:
    # bn-dev-5.2.8482-dev commercial-linux.zip
    # bn-release-5.1.8104 commercial-win64.zip
    # bn-release-5.1.8104 commercial-macos.zip
    extracted_part=""
    os_type=""
    if [[ "$filename_no_ext" =~ ^bn-(.*)\ commercial-(linux|win64|macos)$ ]]; then
        extracted_part="${BASH_REMATCH[1]}"
        os_type="${BASH_REMATCH[2]}"
    else
        echo "Could not parse filename for version/edition and OS: $filename"
        continue
    fi

    # Determine if it's a stable version and construct the output filename part
    version_and_edition=""
    if [[ "$extracted_part" == release-* ]]; then
        # For "release-5.1.8104", the output should be "stable_commercial.5.1.8104"
        version_and_edition="stable_commercial.${extracted_part#release-}"
    elif [[ "$extracted_part" == dev-* ]]; then
        # For "dev-5.2.8482-dev", the output should be "commercial.${version}"
        version_and_edition="commercial.${extracted_part#dev-}"
    else
        echo "Unknown edition type in filename: $filename"
        continue
    fi

    # The new filename should be like binaryninja_linux_stable_commercial.5.1.8005.7z
    # or binaryninja_linux_commercial.5.2.8089-dev.7z
    output_filename="binaryninja_${os_type}_${version_and_edition}.7z"
    output_path="$(realpath $(dirname "$zip_file"))/$output_filename"

    # Check if output file already exists and prompt for confirmation
    if [[ -f "$output_path" ]]; then
        read -r -p "Output file '$output_filename' already exists. Overwrite? (y/N) " response
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "Skipping '$zip_file' as output file '$output_filename' already exists and overwrite was declined."
            continue
        fi
    fi

    # 3. Unpack to a temp folder, it should contains a single folder
    temp_dir=$(mktemp -d -t bn-repack-XXXXXXXX)
    echo "Unpacking to temporary directory: $temp_dir"
    unzip -q "$zip_file" -d "$temp_dir"

    # Find the single folder inside the temporary directory
    unpacked_folder=""
    # Use find to get directories at depth 1
    mapfile -t subdirs < <(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d)

    if [[ ${#subdirs[@]} -eq 1 ]]; then
        unpacked_folder="${subdirs[0]}"
        echo "Found unpacked folder: $unpacked_folder"

        # Rename the unpacked folder to 'binaryninja'
        new_unpacked_folder="${temp_dir}/binaryninja"
        mv "$unpacked_folder" "$new_unpacked_folder"
        unpacked_folder="$new_unpacked_folder"
        echo "Renamed unpacked folder to: $unpacked_folder"
    else
        echo "Expected a single folder inside the zip, but found ${#subdirs[@]}."
        echo "Contents of $temp_dir:"
        ls -F "$temp_dir"
        rm -rf "$temp_dir"
        continue
    fi

    # 4. Repack to 7z: 7z a -snl -snh -mx9

    pwd
    echo "Repacking '$unpacked_folder' to '$output_path'"
    # cd into the parent directory of the unpacked folder to archive its contents directly
    (cd "$(dirname "$unpacked_folder")" && 7z a -snl -snh -mx9 "$output_path" "$(basename "$unpacked_folder")")

    echo "Cleaning up temporary directory: $temp_dir"
    rm -rf "$temp_dir"
    echo "Successfully repacked $zip_file to $output_path"
    echo "--------------------------------------------------"
done

echo "All specified zip files processed."
