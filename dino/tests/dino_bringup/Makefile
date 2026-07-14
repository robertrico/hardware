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
          -ffunction-sections -fdata-sections
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

.PHONY: all size flash clean
