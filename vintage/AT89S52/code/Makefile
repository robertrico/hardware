# Makefile for AT89S52@DIP40 Blinky Program
# Requires SDCC (Small Device C Compiler)
# Install on macOS: brew install sdcc

# Project settings
PROJECT = blink
MCU = mcs51

# Compiler and flags
CC = sdcc
CFLAGS = -mmcs51 --model-small --opt-code-size

# Output files
HEX = $(PROJECT).hex
IHX = $(PROJECT).ihx
BIN = $(PROJECT).bin

# Source files
SRCS = $(PROJECT).c

# Build targets
.PHONY: all clean flash verify

all: $(HEX)

# Compile C to Intel HEX format
$(IHX): $(SRCS)
	$(CC) $(CFLAGS) $(SRCS) -o $(IHX)

# Convert IHX to standard HEX (SDCC outputs .ihx which is Intel HEX format)
$(HEX): $(IHX)
	@cp $(IHX) $(HEX)
	@echo "Build complete: $(HEX)"
	@echo "File size:"
	@ls -lh $(HEX)

# Flash to AT89S52@DIP40 using minipro
flash: $(HEX)
	minipro -p AT89S52@DIP40 -w $(HEX)

# Verify flash contents
verify: $(HEX)
	minipro -p AT89S52@DIP40 -v $(HEX)

# Read device signature
read-signature:
	minipro -p AT89S52@DIP40 -s

# Erase chip
erase:
	minipro -p AT89S52@DIP40 -E

# Clean build artifacts
clean:
	rm -f *.hex *.ihx *.lk *.lst *.map *.mem *.rel *.rst *.sym *.asm *.bin

# Help target
help:
	@echo "AT89S52@DIP40 Blinky Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all              - Build the project (default)"
	@echo "  flash            - Flash the HEX file to AT89S52@DIP40"
	@echo "  verify           - Verify flash contents"
	@echo "  read-signature   - Read device signature"
	@echo "  erase            - Erase the chip"
	@echo "  clean            - Remove build artifacts"
	@echo "  help             - Show this help message"
	@echo ""
	@echo "Requirements:"
	@echo "  - SDCC: brew install sdcc"
	@echo "  - minipro: brew install minipro"
