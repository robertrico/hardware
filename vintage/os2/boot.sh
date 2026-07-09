#!/bin/bash
#
# boot.sh - Launch 86Box virtual machines for OS/2 exploration
#
# Adapted from ../ibm5150/boot.sh. Differences:
#   - Default fresh drive size is configurable (OS/2 1.x wants ~60MB,
#     2.x wants ~100MB, Warp wants ~300MB+).
#   - Adds -b <img>  floppy B (OS/2 1.x installs sometimes want it).
#   - Adds -c <iso>  CD-ROM (Warp and later come on CD).
#   - `new` accepts an optional size in MB as the third argument.
#
# Usage:
#   ./boot.sh                      List machines, drives, media
#   ./boot.sh <machine>            Boot a machine
#   ./boot.sh <machine> -a <img>   Boot with floppy in drive A
#   ./boot.sh <machine> -b <img>   Additionally mount floppy in drive B
#   ./boot.sh <machine> -c <iso>   Additionally mount CD-ROM
#   ./boot.sh <machine> -s         Open 86Box settings only
#   ./boot.sh new <name> [drv] [size_mb]
#                                  Create new machine (fresh drive or link)
#   ./boot.sh drives               List hard drive images
#   ./boot.sh media                List floppy/CD images
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
        bootable=$(python3 -c "
d=open('$img','rb').read(512)
print('bootable' if d[510]==0x55 and d[511]==0xaa else 'empty')
" 2>/dev/null)
        printf "  %-30s %s (%s)\n" "$name" "$size" "$bootable"
    done
    echo
    echo "New drives are created automatically with: $0 new <machine-name> [drive] [size_mb]"
}

list_media() {
    echo "Available media:"
    echo "----------------"
    for subdir in "$MEDIA_DIR"/*/; do
        [ -d "$subdir" ] || continue
        category=$(basename "$subdir")
        echo "  [$category]"
        for img in "$subdir"*.img "$subdir"*.IMG "$subdir"*.iso "$subdir"*.ISO; do
            [ -f "$img" ] || continue
            name=$(basename "$img")
            size=$(ls -lh "$img" | awk '{print $5}')
            printf "    %-45s %s\n" "$name" "$size"
        done
    done
}

create_machine() {
    name="$1"
    drive="$2"
    size_mb="${3:-60}"   # OS/2 1.x friendly default

    if [ -z "$name" ]; then
        echo "Usage: $0 new <machine-name> [drive-image] [size_mb]"
        echo "  e.g.  $0 new at_os2                 # fresh 60MB drive"
        echo "        $0 new warp \"\" 300          # fresh 300MB drive"
        echo "        $0 new test existing.img      # link existing"
        exit 1
    fi

    machine_dir="$MACHINES_DIR/$name"
    if [ -d "$machine_dir" ]; then
        echo "Error: Machine '$name' already exists"
        exit 1
    fi

    mkdir -p "$machine_dir/nvr"

    if [ -n "$drive" ]; then
        if [ -f "$DRIVES_DIR/$drive" ]; then
            ln -sf "../../drives/$drive" "$machine_dir/drive_c.img"
            echo "Linked drive: $drive"
        else
            echo "Error: Drive '$drive' not found in $DRIVES_DIR"
            rm -rf "$machine_dir"
            exit 1
        fi
    else
        drive="${name}.img"
        # sectors = size_mb * 2048 (512-byte sectors)
        sectors=$(( size_mb * 2048 ))
        echo "Creating ${size_mb}MB drive: $drive"
        dd if=/dev/zero of="$DRIVES_DIR/$drive" bs=512 count=$sectors 2>/dev/null
        ln -sf "../../drives/$drive" "$machine_dir/drive_c.img"
        echo "  Drive is raw. You'll need to open 86Box settings to attach"
        echo "  it to the controller with the right geometry, and boot an"
        echo "  OS/2 install floppy to partition/format."
        echo "  Run: $0 $name -s"
    fi

    echo "Created machine: $name"
    echo "  Path: $machine_dir"
    echo "  Config: (none yet — use: $0 $name -s   to configure in 86Box)"
    echo
    echo "Next: launch the settings UI and pick a machine type, then"
    echo "attach drive_c.img and the install floppies."
}

set_cfg_kv() {
    # set_cfg_kv <cfg-file> <section> <key> <value>
    local cfg="$1" section="$2" key="$3" value="$4"
    if grep -q "^${key} = " "$cfg"; then
        sed -i '' "s|^${key} = .*|${key} = ${value}|" "$cfg"
    else
        # append inside the section if it exists, else append section
        if grep -q "^\[${section}\]" "$cfg"; then
            sed -i '' "/^\[${section}\]/a\\
${key} = ${value}
" "$cfg"
        else
            printf "\n[%s]\n%s = %s\n" "$section" "$key" "$value" >> "$cfg"
        fi
    fi
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
    floppy_a=""
    floppy_b=""
    cdrom=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -a) shift; floppy_a="$1" ;;
            -b) shift; floppy_b="$1" ;;
            -c) shift; cdrom="$1" ;;
            -s) extra_args="$extra_args -S" ;;
        esac
        shift
    done

    resolve_media() {
        # resolve_media <name> -> full path or empty
        local f="$1"
        if [ -f "$f" ]; then echo "$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"; return; fi
        for subdir in "$MEDIA_DIR"/*/; do
            if [ -f "$subdir$f" ]; then echo "${subdir}${f}"; return; fi
        done
        echo ""
    }

    cfg="$machine_dir/86box.cfg"
    if [ ! -f "$cfg" ]; then
        echo "Note: no config yet — launching 86Box settings. Configure and save."
        "$EIGHTY_SIX_BOX" -P "$machine_dir" -S
        return
    fi

    if [ -n "$floppy_a" ]; then
        p=$(resolve_media "$floppy_a")
        if [ -n "$p" ]; then
            echo "Floppy A: $p"
            set_cfg_kv "$cfg" "Floppy and CD-ROM drives" "fdd_01_fn" "$p"
        else
            echo "Warning: floppy '$floppy_a' not found"
        fi
    fi
    if [ -n "$floppy_b" ]; then
        p=$(resolve_media "$floppy_b")
        if [ -n "$p" ]; then
            echo "Floppy B: $p"
            set_cfg_kv "$cfg" "Floppy and CD-ROM drives" "fdd_02_fn" "$p"
        fi
    fi
    if [ -n "$cdrom" ]; then
        p=$(resolve_media "$cdrom")
        if [ -n "$p" ]; then
            echo "CD-ROM: $p"
            set_cfg_kv "$cfg" "Floppy and CD-ROM drives" "cdrom_01_image_path" "$p"
            set_cfg_kv "$cfg" "Floppy and CD-ROM drives" "cdrom_01_parameters" "0, image"
        fi
    fi

    echo "Booting: $name"
    [ -L "$machine_dir/drive_c.img" ] && echo "  Drive: $(readlink "$machine_dir/drive_c.img")"

    "$EIGHTY_SIX_BOX" -P "$machine_dir" $extra_args
}

case "${1:-}" in
    ""|list)
        list_machines
        echo
        list_drives
        echo
        list_media
        ;;
    drives) list_drives ;;
    media)  list_media ;;
    new)    shift; create_machine "$@" ;;
    *)      boot_machine "$@" ;;
esac
