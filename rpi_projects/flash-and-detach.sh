#!/bin/bash

PROJECT_DIR="$(pwd)"
[ -f "$(dirname "$0")/.env" ] && source "$(dirname "$0")/.env"

if [ -f "$PROJECT_DIR/project.env" ]; then
  source "$PROJECT_DIR/project.env"
else
  echo "No project.env file found. Please create one or set the ELF_FILE variable."
  exit 1
fi

ELF_FILE="$PROJECT_DIR/build/${ELF_FILE}.elf"

if [ -z "$ELF_FILE" ]; then
  echo "No .elf file found in $PROJECT_DIR/build"
  exit 1
fi
echo "Flashing $ELF_FILE"

GDB="${GDB:-gdb}"

"$GDB" "$ELF_FILE" \
  -ex "target extended-remote localhost:3333" \
  -ex "monitor reset init" \
  -ex "load" \
  -ex "monitor reset run" \
  -ex "detach" \
  -ex "quit"
