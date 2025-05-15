#!/bin/bash

# Go to the directory the script was launched *from*
PROJECT_DIR="$(pwd)"

# Optional: Show where we're working
echo "Using project directory: $PROJECT_DIR"

# Load shared global config
[ -f "$(dirname "$0")/.env" ] && source "$(dirname "$0")/.env"

if [ -f "$PROJECT_DIR/project.env" ]; then
  source "$PROJECT_DIR/project.env"
else
  echo "No project.env file found. Please create one or set the ELF_FILE variable."
  exit 1
fi

# Look for an ELF in build directory relative to project
ELF_FILE="$PROJECT_DIR/build/${ELF_FILE}.elf"

if [ -z "$ELF_FILE" ]; then
  echo "No .elf file found in $PROJECT_DIR/build"
  exit 1
fi

# Use GDB from env or fallback
GDB="${GDB:-gdb}"

"$GDB" "$ELF_FILE" \
  -ex "target extended-remote localhost:3333" \
  -ex "monitor reset init" \
  -ex "load" \
  -ex "echo Program loaded from $ELF_FILE\n" \
  -ex "layout src" \
  -ex "break main" \
  -ex "continue"
