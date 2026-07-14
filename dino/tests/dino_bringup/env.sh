# source me:  source env.sh
export DINO_RIG_PORT="${DINO_RIG_PORT:-$(ls /dev/tty.usbmodem* 2>/dev/null | head -1)}"
build()   { make PORT="$DINO_RIG_PORT"; }
flash()   { make PORT="$DINO_RIG_PORT" flash; }
monitor() { screen "$DINO_RIG_PORT" 115200; }   # exit: ctrl-a k
