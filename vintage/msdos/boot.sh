#!/bin/bash
#
# boot.sh - Launch 86Box virtual machines
#
# Usage:
#   ./boot.sh                     List available machines
#   ./boot.sh <machine>           Boot a machine
#   ./boot.sh <machine> -a <img>  Boot with floppy in drive A
#   ./boot.sh <machine> -s        Open 86Box settings only
#   ./boot.sh new <name>           Create new machine with a fresh 20MB drive
#   ./boot.sh new <name> <drive>   Create new machine linked to existing drive
#   ./boot.sh drives               List available hard drive images
#   ./boot.sh media                List available floppy/media images
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACHINES_DIR="$SCRIPT_DIR/machines"
DRIVES_DIR="$SCRIPT_DIR/drives"
MEDIA_DIR="$SCRIPT_DIR/media"
EIGHTY_SIX_BOX="/Applications/86Box.app/Contents/MacOS/86Box"

if [ ! -x "$EIGHTY_SIX_BOX" ]; then
    echo "Error: 86Box not found at $EIGHTY_SIX_BOX"
    exit 1
fi

list_machines() {
    echo "Available machines:"
    echo "-------------------"
    for dir in "$MACHINES_DIR"/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        cfg="$dir/86box.cfg"
        if [ -f "$cfg" ]; then
            machine=$(grep '^machine = ' "$cfg" | cut -d= -f2 | xargs)
            mem=$(grep '^mem_size = ' "$cfg" | cut -d= -f2 | xargs)
            # Show linked drive
            drive=""
            if [ -L "$dir/drive_c.img" ]; then
                drive=$(basename "$(readlink "$dir/drive_c.img")")
            elif [ -f "$dir/drive_c.img" ]; then
                drive="drive_c.img (local)"
            fi
            printf "  %-20s %s, %sKB RAM" "$name" "$machine" "$mem"
            [ -n "$drive" ] && printf ", drive: %s" "$drive"
            echo
        fi
    done
}

list_drives() {
    echo "Available drives:"
    echo "-----------------"
    for img in "$DRIVES_DIR"/*.img; do
        [ -f "$img" ] || continue
        name=$(basename "$img")
        size=$(ls -lh "$img" | awk '{print $5}')
        # Check if bootable
        bootable=$(python3 -c "
d=open('$img','rb').read(512)
print('bootable' if d[510]==0x55 and d[511]==0xaa else 'empty')
" 2>/dev/null)
        printf "  %-30s %s (%s)\n" "$name" "$size" "$bootable"
    done
    echo
    echo "New drives are created automatically with: $0 new <machine-name>"
}

list_media() {
    echo "Available media:"
    echo "----------------"
    for subdir in "$MEDIA_DIR"/*/; do
        [ -d "$subdir" ] || continue
        category=$(basename "$subdir")
        echo "  [$category]"
        for img in "$subdir"*.img "$subdir"*.IMG; do
            [ -f "$img" ] || continue
            name=$(basename "$img")
            size=$(ls -lh "$img" | awk '{print $5}')
            printf "    %-35s %s\n" "$name" "$size"
        done
    done
}

create_machine() {
    name="$1"
    drive="$2"

    if [ -z "$name" ]; then
        echo "Usage: $0 new <machine-name> [drive-image]"
        exit 1
    fi

    machine_dir="$MACHINES_DIR/$name"
    if [ -d "$machine_dir" ]; then
        echo "Error: Machine '$name' already exists"
        exit 1
    fi

    mkdir -p "$machine_dir/nvr"

    # Link existing drive or create a fresh one
    if [ -n "$drive" ]; then
        if [ -f "$DRIVES_DIR/$drive" ]; then
            ln -sf "../../drives/$drive" "$machine_dir/drive_c.img"
            echo "Linked drive: $drive"
        else
            echo "Error: Drive '$drive' not found in $DRIVES_DIR"
            echo "Available: $(ls "$DRIVES_DIR"/*.img 2>/dev/null | xargs -I{} basename {})"
            rm -rf "$machine_dir"
            exit 1
        fi
    else
        # Create a fresh 20MB drive (615 cyl × 4 heads × 17 spt × 512 bytes)
        drive="${name}.img"
        echo "Creating 20MB drive: $drive"
        dd if=/dev/zero of="$DRIVES_DIR/$drive" bs=512 count=41820 2>/dev/null
        ln -sf "../../drives/$drive" "$machine_dir/drive_c.img"
        echo "  Drive needs formatting. Boot with a DOS floppy:"
        echo "    $0 $name -a pcdos330_disk1.img"
        echo "  Then: FDISK, FORMAT C: /S"
    fi

    # Copy default config from an existing machine as a template.
    # Prefer guide-standard names, then any other machine.
    template=""
    for cand in "$MACHINES_DIR"/pc_5150/86box.cfg \
                "$MACHINES_DIR"/xt_5160/86box.cfg \
                "$MACHINES_DIR"/at_5170/86box.cfg \
                "$MACHINES_DIR"/deskpro_386/86box.cfg; do
        if [ -f "$cand" ] && [ "$cand" != "$machine_dir/86box.cfg" ]; then
            template="$cand"
            break
        fi
    done
    if [ -z "$template" ]; then
        for cfg in "$MACHINES_DIR"/*/86box.cfg; do
            [ -f "$cfg" ] || continue
            [ "$cfg" = "$machine_dir/86box.cfg" ] && continue
            template="$cfg"
            break
        done
    fi
    if [ -n "$template" ]; then
        cp "$template" "$machine_dir/86box.cfg"
        echo "Template: $(basename "$(dirname "$template")")/86box.cfg"
        echo "  Edit $machine_dir/86box.cfg to match the target era."
    else
        echo "Warning: No template config found. Launch with -s to configure."
    fi

    echo "Created machine: $name"
    echo "  Path: $machine_dir"
    echo "  Config: $machine_dir/86box.cfg"
    [ -n "$drive" ] && echo "  Drive: $drive"
    echo
    echo "Boot with: $0 $name"
}

boot_machine() {
    name="$1"
    shift

    machine_dir="$MACHINES_DIR/$name"
    if [ ! -d "$machine_dir" ]; then
        echo "Error: Machine '$name' not found"
        echo
        list_machines
        exit 1
    fi

    extra_args=""
    floppy_path=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -a)
                shift
                floppy="$1"
                # Resolve floppy path - check media dirs
                if [ ! -f "$floppy" ]; then
                    for subdir in "$MEDIA_DIR"/*/; do
                        if [ -f "$subdir$floppy" ]; then
                            floppy="$subdir$floppy"
                            break
                        fi
                    done
                fi
                if [ -f "$floppy" ]; then
                    floppy_path="$(cd "$(dirname "$floppy")" && pwd)/$(basename "$floppy")"
                    echo "Floppy A: $floppy_path"
                else
                    echo "Warning: Floppy image '$1' not found"
                fi
                ;;
            -s)
                extra_args="$extra_args -S"
                ;;
        esac
        shift
    done

    # Write floppy path into config if specified
    cfg="$machine_dir/86box.cfg"
    if [ -n "$floppy_path" ] && [ -f "$cfg" ]; then
        # Update or insert fdd_01_fn in the config
        if grep -q '^fdd_01_fn' "$cfg"; then
            sed -i '' "s|^fdd_01_fn.*|fdd_01_fn = $floppy_path|" "$cfg"
        else
            sed -i '' "/^\[Floppy and CD-ROM drives\]/a\\
fdd_01_fn = $floppy_path
" "$cfg"
        fi
    fi

    echo "Booting: $name"
    echo "  Path: $machine_dir"
    [ -L "$machine_dir/drive_c.img" ] && echo "  Drive: $(readlink "$machine_dir/drive_c.img")"
    echo

    "$EIGHTY_SIX_BOX" -P "$machine_dir" $extra_args
}

# Main
case "${1:-}" in
    ""|list)
        list_machines
        echo
        list_drives
        echo
        list_media
        ;;
    drives)
        list_drives
        ;;
    media)
        list_media
        ;;
    new)
        shift
        create_machine "$@"
        ;;
    *)
        boot_machine "$@"
        ;;
esac
