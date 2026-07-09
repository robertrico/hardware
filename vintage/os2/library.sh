#!/bin/bash
#
# library.sh - Search and extract disk images from the PCjs library
#
# Usage:
#   ./library.sh search <term>          Search for disk images by name
#   ./library.sh list <category>        List disks in a category
#   ./library.sh categories             List available categories
#   ./library.sh extract <json-path>    Convert JSON disk to .img in media/
#   ./library.sh info <json-path>       Show disk contents without extracting
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PCJS_DIR="$SCRIPT_DIR/pcjs"
TOOLS_DIR="$PCJS_DIR/tools"
DISKIMAGE="$TOOLS_DIR/tools/diskimage/diskimage.js"
MEDIA_DIR="$SCRIPT_DIR/media"

# Disk repos in order of interest
REPOS=("diskettes" "gamedisks" "miscdisks")

check_repos() {
    for repo in "${REPOS[@]}"; do
        if [ ! -d "$PCJS_DIR/$repo" ]; then
            echo "Error: $repo not cloned. Run:"
            echo "  cd pcjs && git clone --depth 1 https://github.com/jeffpar/pcjs-${repo}.git ${repo}"
            exit 1
        fi
    done
}

search_disks() {
    term="$1"
    if [ -z "$term" ]; then
        echo "Usage: $0 search <term>"
        exit 1
    fi

    echo "Searching for: $term"
    echo "==============================================="

    for repo in "${REPOS[@]}"; do
        repo_dir="$PCJS_DIR/$repo"
        [ -d "$repo_dir" ] || continue

        results=$(find "$repo_dir" -name "*.json" -not -name "diskettes.json" -not -name "package.json" \
            | grep -i "$term" \
            | sed "s|$PCJS_DIR/||" \
            | sort)

        if [ -n "$results" ]; then
            echo
            echo "[$repo]"
            echo "$results" | while read -r path; do
                # Clean up path for display
                display=$(echo "$path" | sed "s|^${repo}/pcx86/||")
                echo "  $display"
            done
        fi
    done
}

list_category() {
    category="$1"

    if [ -z "$category" ]; then
        echo "Usage: $0 list <category>"
        echo
        echo "Examples:"
        echo "  $0 list sys/dos/ibm"
        echo "  $0 list game/infocom"
        echo "  $0 list app"
        exit 1
    fi

    for repo in "${REPOS[@]}"; do
        repo_dir="$PCJS_DIR/$repo/pcx86/$category"
        [ -d "$repo_dir" ] || continue

        echo "[$repo] pcx86/$category"
        echo "-------------------------------------------"
        find "$repo_dir" -name "*.json" -not -name "diskettes.json" \
            | sed "s|$PCJS_DIR/$repo/pcx86/$category/||" \
            | sort \
            | while read -r path; do
                echo "  $path"
            done
        echo
    done
}

list_categories() {
    echo "Available categories:"
    echo "====================="

    for repo in "${REPOS[@]}"; do
        repo_dir="$PCJS_DIR/$repo/pcx86"
        [ -d "$repo_dir" ] || continue

        echo
        echo "[$repo]"
        # List top two levels of directories
        find "$repo_dir" -mindepth 1 -maxdepth 2 -type d \
            | sed "s|$repo_dir/||" \
            | sort \
            | while read -r dir; do
                count=$(find "$PCJS_DIR/$repo/pcx86/$dir" -name "*.json" -not -name "diskettes.json" 2>/dev/null | wc -l | tr -d ' ')
                [ "$count" -gt 0 ] && printf "  %-40s (%s disks)\n" "$dir" "$count"
            done
    done
}

extract_disk() {
    json_path="$1"
    dest_subdir="${2:-extracted}"

    if [ -z "$json_path" ]; then
        echo "Usage: $0 extract <path-to-json> [media-subdir]"
        echo
        echo "Examples:"
        echo "  $0 extract diskettes/pcx86/sys/dos/ibm/3.30/PCDOS330-DISK1.json dos"
        echo "  $0 extract gamedisks/pcx86/game/infocom/zork1/ZORK1.json games"
        exit 1
    fi

    # Resolve full path
    full_path="$PCJS_DIR/$json_path"
    if [ ! -f "$full_path" ]; then
        # Try finding it
        found=$(find "$PCJS_DIR" -path "*$json_path*" -name "*.json" -not -name "diskettes.json" | head -1)
        if [ -n "$found" ]; then
            full_path="$found"
        else
            echo "Error: $json_path not found"
            echo "Try: $0 search $(basename "$json_path" .json)"
            exit 1
        fi
    fi

    # Output filename
    basename_no_ext=$(basename "$full_path" .json)
    output_dir="$MEDIA_DIR/$dest_subdir"
    mkdir -p "$output_dir"
    output_file="$output_dir/$basename_no_ext.img"

    if [ -f "$output_file" ]; then
        echo "Already extracted: $output_file"
        return 0
    fi

    echo "Converting: $(echo "$full_path" | sed "s|$PCJS_DIR/||")"
    echo "Output:     $output_file"

    node "$DISKIMAGE" --disk="$full_path" --output="$output_file" 2>&1

    if [ -f "$output_file" ]; then
        size=$(ls -lh "$output_file" | awk '{print $5}')
        echo "Done: $output_file ($size)"
    else
        echo "Error: conversion failed"
    fi
}

disk_info() {
    json_path="$1"

    if [ -z "$json_path" ]; then
        echo "Usage: $0 info <path-to-json>"
        exit 1
    fi

    full_path="$PCJS_DIR/$json_path"
    if [ ! -f "$full_path" ]; then
        found=$(find "$PCJS_DIR" -path "*$json_path*" -name "*.json" -not -name "diskettes.json" | head -1)
        if [ -n "$found" ]; then
            full_path="$found"
        else
            echo "Error: $json_path not found"
            exit 1
        fi
    fi

    echo "Disk: $(echo "$full_path" | sed "s|$PCJS_DIR/||")"
    echo "-------------------------------------------"
    node "$DISKIMAGE" --disk="$full_path" --list 2>&1
}

# Main
case "${1:-}" in
    search)
        check_repos
        shift
        search_disks "$@"
        ;;
    list)
        check_repos
        shift
        list_category "$@"
        ;;
    categories)
        check_repos
        list_categories
        ;;
    extract)
        check_repos
        shift
        extract_disk "$@"
        ;;
    info)
        check_repos
        shift
        disk_info "$@"
        ;;
    *)
        echo "PCjs Disk Image Library"
        echo "======================="
        echo
        echo "Usage:"
        echo "  $0 search <term>          Search for disk images"
        echo "  $0 list <category>        List disks in a category"
        echo "  $0 categories             List all categories"
        echo "  $0 extract <json> [dir]   Convert to .img in media/<dir>"
        echo "  $0 info <json>            Show disk contents"
        echo
        echo "Examples:"
        echo "  $0 search wordperfect"
        echo "  $0 search zork"
        echo "  $0 list sys/dos/ibm"
        echo "  $0 list game/infocom"
        echo "  $0 extract diskettes/pcx86/sys/dos/ibm/3.30/PCDOS330-DISK1.json dos"
        echo "  $0 extract gamedisks/pcx86/game/infocom/zork1/ZORK1.json games"
        ;;
esac
