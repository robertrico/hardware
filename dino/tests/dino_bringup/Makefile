# DINO bring-up rig — ATmega2560, bare-metal avr-gcc
MCU     = atmega2560
F_CPU   = 16000000UL
PORT   ?= $(firstword $(wildcard /dev/tty.usbmodem*))
TARGET  = dino_bringup
BUILD   = build
SRC     = $(wildcard src/*.c)
OBJ     = $(SRC:src/%.c=$(BUILD)/%.o)

CC      = avr-gcc
CFLAGS  = -mmcu=$(MCU) -DF_CPU=$(F_CPU) -Os -std=gnu99 -Wall -Wextra -Werror \
          -ffunction-sections -fdata-sections -MMD -MP
LDFLAGS = -mmcu=$(MCU) -Wl,--gc-sections

all: $(BUILD)/$(TARGET).hex size

$(BUILD)/%.o: src/%.c | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/$(TARGET).elf: $(OBJ)
	$(CC) $(LDFLAGS) $^ -o $@

$(BUILD)/$(TARGET).hex: $(BUILD)/$(TARGET).elf
	avr-objcopy -O ihex -R .eeprom $< $@

$(BUILD):
	mkdir -p $(BUILD)

size: $(BUILD)/$(TARGET).elf
	avr-size --format=avr --mcu=$(MCU) $<

flash: $(BUILD)/$(TARGET).hex
	avrdude -c wiring -p m2560 -P $(PORT) -b 115200 -D -U flash:w:$<:i

clean:
	rm -rf $(BUILD)

# ---- microcode ROM burning (TL866 via minipro, AT28C64B) ----
# Bins from: python3 ../../docs/notes/microcode_gen.py
# U9 = word[7:0] = CW0-7 (LOW byte), U15 = word[15:8] = CW8-15 (HIGH).
# minipro verifies after every write; `make id-rom` names whatever chip
# is in the socket; verify-* does an explicit read+compare.
MINIPRO  ?= minipro
# AT28C64B (with the B): that db entry carries the SDP unlock + page-write
# algorithm; the plain AT28C64 entry write-fails on B-suffix parts.
ROM_CHIP ?= AT28C64B
ROMS      = ../../roms

burn-diag-u9:
	$(MINIPRO) -p $(ROM_CHIP) -w $(ROMS)/U9_diag.bin
burn-diag-u15:
	$(MINIPRO) -p $(ROM_CHIP) -w $(ROMS)/U15_diag.bin
burn-real-u9:
	$(MINIPRO) -p $(ROM_CHIP) -w $(ROMS)/U9.bin
burn-real-u15:
	$(MINIPRO) -p $(ROM_CHIP) -w $(ROMS)/U15.bin

# ---- program ROM (AT28C256, the memory board's U24) ----
# Bins from: python3 ../../docs/notes/progrom_gen.py
# Burn DIAG first (memory.romorder proves all 15 address lines), then REAL.
PROG_CHIP ?= AT28C256

burn-prog-diag:
	$(MINIPRO) -p $(PROG_CHIP) -w $(ROMS)/PROG_diag.bin
burn-prog:
	$(MINIPRO) -p $(PROG_CHIP) -w $(ROMS)/PROG.bin
read-prog: | $(BUILD)
	$(MINIPRO) -p $(PROG_CHIP) -r $(BUILD)/prog_read.bin
verify-prog-diag: read-prog
	cmp $(BUILD)/prog_read.bin $(ROMS)/PROG_diag.bin && echo "PROG DIAG verified"
verify-prog: read-prog
	cmp $(BUILD)/prog_read.bin $(ROMS)/PROG.bin && echo "PROG REAL verified"

read-rom: | $(BUILD)
	$(MINIPRO) -p $(ROM_CHIP) -r $(BUILD)/rom_read.bin

id-rom: read-rom
	@for f in U9_diag U15_diag U9 U15; do \
	  if cmp -s $(BUILD)/rom_read.bin $(ROMS)/$$f.bin; then \
	    echo "chip in socket == $$f.bin"; exit 0; fi; \
	done; \
	echo "chip matches NO known image (blank, stale, or corrupt burn)"; exit 1

verify-diag-u9: read-rom
	cmp $(BUILD)/rom_read.bin $(ROMS)/U9_diag.bin && echo "U9 DIAG verified"
verify-diag-u15: read-rom
	cmp $(BUILD)/rom_read.bin $(ROMS)/U15_diag.bin && echo "U15 DIAG verified"
verify-real-u9: read-rom
	cmp $(BUILD)/rom_read.bin $(ROMS)/U9.bin && echo "U9 REAL verified"
verify-real-u15: read-rom
	cmp $(BUILD)/rom_read.bin $(ROMS)/U15.bin && echo "U15 REAL verified"

# header deps (pinmap_gen.h regeneration must rebuild dependents)
-include $(OBJ:.o=.d)

.PHONY: all size flash clean \
        burn-diag-u9 burn-diag-u15 burn-real-u9 burn-real-u15 \
        burn-prog-diag burn-prog read-prog verify-prog-diag verify-prog \
        read-rom id-rom \
        verify-diag-u9 verify-diag-u15 verify-real-u9 verify-real-u15
