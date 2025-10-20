# SBC09 - 6809 Simulator and Assembler
# Modernized Makefile

# Compiler and flags
CC = gcc
CFLAGS = -O2 -Wall
V09FLAGS = -DUSE_TERMIOS

# Directories
LIB_DIR = lib
SRC_DIR = src
BUILD_DIR = build
EMU_DIR = $(LIB_DIR)/emulator
ASM_DIR = $(LIB_DIR)/assembler
MON_DIR = $(LIB_DIR)/monitor
EXAMPLES_DIR = $(SRC_DIR)/examples
PROGRAMS_DIR = $(SRC_DIR)/programs
FORTH_DIR = $(SRC_DIR)/forth
BASIC_DIR = $(SRC_DIR)/basic

# Source files
V09_SRCS = $(EMU_DIR)/v09.c $(EMU_DIR)/engine.c $(EMU_DIR)/io.c
V09_OBJS = $(BUILD_DIR)/v09.o $(BUILD_DIR)/engine.o $(BUILD_DIR)/io.o
A09_SRC = $(ASM_DIR)/a09.c
MAKEROM_SRC = $(LIB_DIR)/makerom.c

# Executables
V09 = v09
A09 = a09
MAKEROM = makerom
ROM = v09.rom

# Default target
.PHONY: all
all: $(V09) $(A09) $(ROM) examples

# Build v09 emulator
$(V09): $(V09_OBJS)
	$(CC) -o $@ $(CFLAGS) $^
	@echo "Built v09 emulator"

$(BUILD_DIR)/v09.o: $(EMU_DIR)/v09.c $(EMU_DIR)/v09.h
	@mkdir -p $(BUILD_DIR)
	$(CC) -c $(CFLAGS) $(V09FLAGS) -o $@ $<

$(BUILD_DIR)/engine.o: $(EMU_DIR)/engine.c $(EMU_DIR)/v09.h
	@mkdir -p $(BUILD_DIR)
	$(CC) -c $(CFLAGS) $(V09FLAGS) -o $@ $<

$(BUILD_DIR)/io.o: $(EMU_DIR)/io.c $(EMU_DIR)/v09.h
	@mkdir -p $(BUILD_DIR)
	$(CC) -c $(CFLAGS) $(V09FLAGS) -o $@ $<

# Build a09 assembler
$(A09): $(A09_SRC)
	$(CC) -o $@ $(CFLAGS) $<
	@echo "Built a09 assembler"

# Build makerom utility
$(MAKEROM): $(MAKEROM_SRC)
	$(CC) -o $@ $(CFLAGS) $<
	@echo "Built makerom utility"

# Build ROM - use pre-built alt09.rom (includes Forth)
$(ROM): alt09.rom
	@cp alt09.rom $(ROM)
	@echo "Using alt09.rom (includes Forth and TETRIS)"

# Build monitor-only ROM from source (optional)
.PHONY: monitor-rom
monitor-rom: $(MAKEROM) $(BUILD_DIR)/monitor.s
	./$(MAKEROM) < $(BUILD_DIR)/monitor.s
	@mv v09.rom v09-monitor-only.rom
	@echo "Built monitor-only ROM as v09-monitor-only.rom"

$(BUILD_DIR)/monitor.s: $(A09) $(MON_DIR)/monitor.asm
	@mkdir -p $(BUILD_DIR)
	./$(A09) -s $@ -l $(BUILD_DIR)/monitor.lst $(MON_DIR)/monitor.asm
	@echo "Assembled monitor"

# Build examples
.PHONY: examples
examples: $(A09)
	@echo "Building examples..."
	@mkdir -p $(BUILD_DIR)/examples
	@./$(A09) -l $(BUILD_DIR)/examples/test09.lst $(EXAMPLES_DIR)/test09.asm
	@./$(A09) -l $(BUILD_DIR)/examples/bench09.lst $(EXAMPLES_DIR)/bench09.asm
	@./$(A09) -l $(BUILD_DIR)/examples/bin2dec.lst $(EXAMPLES_DIR)/bin2dec.asm
	@./$(A09) -l $(BUILD_DIR)/examples/asmtest.lst $(EXAMPLES_DIR)/asmtest.asm
	@echo "Examples built successfully"

# Build BASIC interpreter
.PHONY: basic
basic: $(A09)
	@mkdir -p $(BUILD_DIR)/basic
	./$(A09) -o $(BUILD_DIR)/basic/basic -l $(BUILD_DIR)/basic/basic.lst $(BASIC_DIR)/basic.asm
	@echo "Built BASIC interpreter"
	@echo ""
	@echo "To run BASIC:"
	@echo "  1. ./v09"
	@echo "  2. At . prompt: XL400 (Enter, then Ctrl-])"
	@echo "  3. At v09> prompt: Ubuild/basic/basic (Enter)"
	@echo "  4. Wait for transfer"
	@echo "  5. At . prompt: G400"
	@echo ""
	@echo "Then try: 10 PRINT \"HELLO\" : 20 END : RUN"

# Clean build artifacts
.PHONY: clean
clean:
	rm -f $(V09) $(A09) $(MAKEROM)
	rm -f $(ROM) v09.rom.backup
	rm -rf $(BUILD_DIR)
	@echo "Cleaned build artifacts"

# Clean everything including executables
.PHONY: distclean
distclean: clean
	rm -f *.log
	@echo "Deep clean complete"

# Install (copy executables to /usr/local/bin - requires sudo)
.PHONY: install
install: all
	@echo "Installing to /usr/local/bin (requires sudo)"
	sudo cp $(V09) /usr/local/bin/
	sudo cp $(A09) /usr/local/bin/
	@echo "Installation complete"

# Uninstall
.PHONY: uninstall
uninstall:
	sudo rm -f /usr/local/bin/$(V09)
	sudo rm -f /usr/local/bin/$(A09)
	@echo "Uninstalled"

# Kill any running v09 emulator processes
.PHONY: kill
kill:
	@pkill -9 v09 2>/dev/null && echo "Killed v09 processes" || echo "No v09 processes running"

# Build a user program (usage: make program PROJECT=hello)
# Looks for src/programs/$(PROJECT).asm and builds to build/programs/$(PROJECT)
.PHONY: program
program: $(A09)
ifndef PROJECT
	@echo "Error: PROJECT variable not set"
	@echo "Usage: make program PROJECT=hello"
	@echo "This will assemble src/programs/hello.asm to build/programs/hello"
	@exit 1
endif
	@echo "Building program: $(PROJECT)"
	@mkdir -p $(BUILD_DIR)/programs
	./$(A09) -o $(BUILD_DIR)/programs/$(PROJECT) -l $(BUILD_DIR)/programs/$(PROJECT).lst $(PROGRAMS_DIR)/$(PROJECT).asm
	@echo "Built $(PROJECT) successfully"
	@echo "  Source:  src/programs/$(PROJECT).asm"
	@echo "  Listing: build/programs/$(PROJECT).lst"
	@echo "  Binary:  build/programs/$(PROJECT)"
	@echo ""
	@echo "To run in emulator:"
	@echo "  1. ./v09"
	@echo "  2. At . prompt type: XL400 (press Enter)"
	@echo "  3. You'll see 'Start XMODEM Send' - press Ctrl-]"
	@echo "  4. At v09> prompt type: Ubuild/programs/$(PROJECT) (press Enter)"
	@echo "  5. Wait for transfer, you'll return to . prompt"
	@echo "  6. At . prompt type: G400 (press Enter)"

# Help target
.PHONY: help
help:
	@echo "SBC09 Build System"
	@echo "=================="
	@echo ""
	@echo "Targets:"
	@echo "  all        - Build emulator, assembler, ROM, and examples (default)"
	@echo "  v09        - Build only the v09 emulator"
	@echo "  a09        - Build only the a09 assembler"
	@echo "  examples   - Build example programs"
	@echo "  basic      - Build BASIC interpreter"
	@echo "  program    - Build a specific program (make program PROJECT=hello)"
	@echo "  clean      - Remove build artifacts"
	@echo "  distclean  - Remove all generated files"
	@echo "  kill       - Kill any running v09 emulator processes"
	@echo "  install    - Install to /usr/local/bin (requires sudo)"
	@echo "  uninstall  - Remove from /usr/local/bin"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Directory Structure:"
	@echo "  lib/          - Library source code (emulator, assembler, monitor)"
	@echo "  src/programs/ - Your 6809 programs (write here!)"
	@echo "  src/examples/ - Example programs included with SBC09"
	@echo "  src/forth/    - Forth system and TETRIS"
	@echo "  src/basic/    - BASIC interpreter"
	@echo "  build/        - Build artifacts and intermediate files"
	@echo ""
	@echo "Usage:"
	@echo "  make                       # Build everything"
	@echo "  make clean                 # Clean build files"
	@echo "  make v09                   # Build just the emulator"
	@echo "  make program PROJECT=hello # Build src/programs/hello.asm"
	@echo "  make kill                  # Kill any running v09 processes"
	@echo "  ./v09                      # Run the emulator"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. Create src/programs/myprogram.asm"
	@echo "  2. make program PROJECT=myprogram"
	@echo "  3. Follow the instructions to run in v09"
