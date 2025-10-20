# 6809_Bootstrap Makefile
# Build system for 6809 development projects

# Paths
AS9       = lib/as9
AS9_SRC   = lib/as9_source
SRC_DIR   = src
BUILD_DIR = build
TEMPLATES = templates
EXAMPLES  = examples

# Default assembler options
ASM_OPTS  = l c s bin s19 cre

# Project variable (set via command line)
PROJECT   ?=
SOURCE    ?= main.asm
OPTIONS   ?= $(ASM_OPTS)

# Colors for output
BOLD      = \033[1m
GREEN     = \033[32m
BLUE      = \033[34m
YELLOW    = \033[33m
RESET     = \033[0m

.PHONY: help new build clean clean-project assembler list examples

# Default target
help:
	@echo "$(BOLD)6809_Bootstrap - Makefile-based Build System$(RESET)"
	@echo ""
	@echo "$(BOLD)Project Management:$(RESET)"
	@echo "  make new PROJECT=<name>           - Create new project"
	@echo "  make build PROJECT=<name>         - Build project (src/<name>/main.asm)"
	@echo "  make clean-project PROJECT=<name> - Clean project build outputs"
	@echo ""
	@echo "$(BOLD)Examples:$(RESET)"
	@echo "  make example-blinker              - Build blinker example"
	@echo "  make example-hello                - Build hello example"
	@echo "  make example-minimal              - Build minimal example"
	@echo ""
	@echo "$(BOLD)Options:$(RESET)"
	@echo "  make build PROJECT=test SOURCE=main.asm OPTIONS=\"l s19\""
	@echo ""
	@echo "$(BOLD)Assembler Options:$(RESET)"
	@echo "  l    - Generate listing file (.lst)"
	@echo "  c    - Include cycle counts in listing"
	@echo "  s    - Generate symbol table (.sym)"
	@echo "  bin  - Generate binary file (.bin)"
	@echo "  s19  - Generate S19 file (.s19) for ROM programming"
	@echo "  cre  - Generate cross-reference (.crf)"
	@echo ""
	@echo "$(BOLD)Maintenance:$(RESET)"
	@echo "  make assembler                    - Rebuild AS9 assembler from source"
	@echo "  make clean                        - Clean all build outputs"
	@echo "  make list                         - List all projects"

# Create new project
new:
	@if [ -z "$(PROJECT)" ]; then \
		echo "$(YELLOW)Error: PROJECT name required$(RESET)"; \
		echo "Usage: make new PROJECT=<name>"; \
		exit 1; \
	fi
	@if [ -d "$(SRC_DIR)/$(PROJECT)" ]; then \
		echo "$(YELLOW)Error: Project '$(PROJECT)' already exists$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BOLD)Creating new 6809 project: $(GREEN)$(PROJECT)$(RESET)"
	@mkdir -p "$(SRC_DIR)/$(PROJECT)"
	@sed "s/\[YOUR_PROJECT_NAME\]/$(PROJECT)/g" "$(TEMPLATES)/minimal.asm" > "$(SRC_DIR)/$(PROJECT)/main.asm"
	@echo "$(GREEN)✓$(RESET) Project created at: $(SRC_DIR)/$(PROJECT)/"
	@echo "$(GREEN)✓$(RESET) Main file: $(SRC_DIR)/$(PROJECT)/main.asm"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Edit: $(SRC_DIR)/$(PROJECT)/main.asm"
	@echo "  2. Build: make build PROJECT=$(PROJECT)"

# Build project
build: $(AS9)
	@if [ -z "$(PROJECT)" ]; then \
		echo "$(YELLOW)Error: PROJECT name required$(RESET)"; \
		echo "Usage: make build PROJECT=<name>"; \
		exit 1; \
	fi
	@if [ ! -f "$(SRC_DIR)/$(PROJECT)/$(SOURCE)" ]; then \
		echo "$(YELLOW)Error: Source not found: $(SRC_DIR)/$(PROJECT)/$(SOURCE)$(RESET)"; \
		echo "Create project first: make new PROJECT=$(PROJECT)"; \
		exit 1; \
	fi
	@mkdir -p "$(BUILD_DIR)/$(PROJECT)"
	@echo "$(BOLD)╔════════════════════════════════════════════════╗$(RESET)"
	@echo "$(BOLD)║      6809_Bootstrap Build System               ║$(RESET)"
	@echo "$(BOLD)╚════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(BOLD)Project:$(RESET)  $(PROJECT)"
	@echo "$(BOLD)Source:$(RESET)   $(SRC_DIR)/$(PROJECT)/$(SOURCE)"
	@echo "$(BOLD)Options:$(RESET)  -$(OPTIONS)"
	@echo "$(BOLD)Output:$(RESET)   $(BUILD_DIR)/$(PROJECT)/"
	@echo ""
	@cp "$(SRC_DIR)/$(PROJECT)/$(SOURCE)" "$(BUILD_DIR)/$(PROJECT)/"
	@echo "Assembling..."
	@if $(AS9) "$(BUILD_DIR)/$(PROJECT)/$(SOURCE)" -$(OPTIONS); then \
		echo ""; \
		echo "$(GREEN)✓ Assembly successful!$(RESET)"; \
		echo ""; \
		echo "Generated files in $(BUILD_DIR)/$(PROJECT)/:"; \
		ls -lh "$(BUILD_DIR)/$(PROJECT)/" | tail -n +2 | awk '{printf "  %-25s %8s\n", $$9, $$5}'; \
		echo ""; \
		BASENAME=$$(basename "$(SOURCE)" .asm); \
		if [ -f "$(BUILD_DIR)/$(PROJECT)/$${BASENAME}.s19" ]; then \
			echo "$(BLUE)📦 ROM file:$(RESET) $(BUILD_DIR)/$(PROJECT)/$${BASENAME}.s19"; \
		fi; \
		if [ -f "$(BUILD_DIR)/$(PROJECT)/$${BASENAME}.lst" ]; then \
			echo "$(BLUE)📄 Listing:$(RESET)  $(BUILD_DIR)/$(PROJECT)/$${BASENAME}.lst"; \
		fi; \
		if [ -f "$(BUILD_DIR)/$(PROJECT)/$${BASENAME}.bin" ]; then \
			SIZE=$$(wc -c < "$(BUILD_DIR)/$(PROJECT)/$${BASENAME}.bin" | tr -d ' '); \
			echo "$(BLUE)💾 Binary:$(RESET)   $(BUILD_DIR)/$(PROJECT)/$${BASENAME}.bin ($${SIZE} bytes)"; \
		fi; \
		echo ""; \
		echo "$(GREEN)✨ Build complete!$(RESET)"; \
	else \
		echo ""; \
		echo "$(YELLOW)✗ Assembly failed - check source for errors$(RESET)"; \
		exit 1; \
	fi

# Example builds
example-%: $(AS9)
	@EXAMPLE_NAME=$*; \
	if [ ! -f "$(EXAMPLES)/$${EXAMPLE_NAME}.asm" ]; then \
		echo "$(YELLOW)Error: Example not found: $(EXAMPLES)/$${EXAMPLE_NAME}.asm$(RESET)"; \
		exit 1; \
	fi; \
	mkdir -p "$(BUILD_DIR)/example_$${EXAMPLE_NAME}"; \
	echo "$(BOLD)Building example: $(GREEN)$${EXAMPLE_NAME}$(RESET)"; \
	cp "$(EXAMPLES)/$${EXAMPLE_NAME}.asm" "$(BUILD_DIR)/example_$${EXAMPLE_NAME}/"; \
	$(AS9) "$(BUILD_DIR)/example_$${EXAMPLE_NAME}/$${EXAMPLE_NAME}.asm" -$(ASM_OPTS); \
	echo "$(GREEN)✓$(RESET) Output in: $(BUILD_DIR)/example_$${EXAMPLE_NAME}/"

# List all projects
list:
	@echo "$(BOLD)Projects in $(SRC_DIR)/:$(RESET)"
	@if [ -d "$(SRC_DIR)" ] && [ -n "$$(ls -A $(SRC_DIR) 2>/dev/null)" ]; then \
		ls -1 "$(SRC_DIR)"; \
	else \
		echo "  (no projects yet)"; \
		echo ""; \
		echo "Create one with: make new PROJECT=<name>"; \
	fi

# Clean project build outputs
clean-project:
	@if [ -z "$(PROJECT)" ]; then \
		echo "$(YELLOW)Error: PROJECT name required$(RESET)"; \
		echo "Usage: make clean-project PROJECT=<name>"; \
		exit 1; \
	fi
	@if [ -d "$(BUILD_DIR)/$(PROJECT)" ]; then \
		rm -rf "$(BUILD_DIR)/$(PROJECT)"; \
		echo "$(GREEN)✓$(RESET) Cleaned: $(BUILD_DIR)/$(PROJECT)/"; \
	else \
		echo "No build outputs for: $(PROJECT)"; \
	fi

# Clean all build outputs
clean:
	@if [ -d "$(BUILD_DIR)" ]; then \
		rm -rf "$(BUILD_DIR)"; \
		echo "$(GREEN)✓$(RESET) Cleaned all build outputs"; \
	else \
		echo "No build outputs to clean"; \
	fi

# Rebuild assembler from source
assembler:
	@echo "$(BOLD)Rebuilding AS9 assembler from source...$(RESET)"
	@cd $(AS9_SRC) && $(MAKE)
	@echo "$(GREEN)✓$(RESET) Assembler rebuilt: $(AS9)"

# Ensure assembler exists
$(AS9):
	@if [ ! -f "$(AS9)" ]; then \
		echo "$(YELLOW)AS9 assembler not found, building...$(RESET)"; \
		$(MAKE) assembler; \
	fi
