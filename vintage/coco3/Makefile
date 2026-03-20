# CoCo 3 Cross-Compilation Makefile
# Requires: cmoc, lwasm, lwlink, decb, os9 (toolshed)
#
# Usage:
#   make PRGM=cshell                - build OS-9 program
#   make PRGM=smiley TARGET=decb    - build Disk BASIC program
#   make deploy PRGM=cshell         - build + deploy OS-9 program to CoCoSDC
#   make dsk PRGM=smiley            - build Disk BASIC program + .dsk image
#   make clean                      - remove build artifacts

PREFIX = $(HOME)/.local/bin
CMOC   = $(PREFIX)/cmoc
DECB   = $(PREFIX)/decb
OS9    = $(PREFIX)/os9

# CoCoSDC SD card paths
SDCARD   = /Volumes/COCO3
VHD      = $(SDCARD)/HDD/63SDC.VHD
CMDS_DIR = $(VHD),CMDS

# Target platform: os9 (default) or decb
TARGET ?= os9

# Guard: PRGM must be provided (except for clean)
ifeq ($(filter clean,$(MAKECMDGOALS)),)
ifndef PRGM
$(error PRGM is required. Usage: make PRGM=<name> [TARGET=os9|decb])
endif
endif

.PHONY: all clean dsk deploy

# --- Build ---
ifeq ($(TARGET),decb)
all: $(PRGM).bin
$(PRGM).bin: $(PRGM).c
	$(CMOC) --coco -o $@ $<
else
all: $(PRGM)
$(PRGM): $(PRGM).c
	$(CMOC) --os9 -o $@ $<
endif

# --- Deploy OS-9 program to NitrOS-9 HDD on CoCoSDC SD card ---
deploy: $(PRGM)
	@test -d $(SDCARD) || (echo "SD card not mounted at $(SDCARD)" && exit 1)
	$(OS9) copy -r $(PRGM) $(CMDS_DIR)/$(PRGM)
	$(OS9) attr $(CMDS_DIR)/$(PRGM) -epe
	@echo "Deployed '$(PRGM)' to $(CMDS_DIR)/$(PRGM)"

# --- Create .dsk image for Disk BASIC / CoCoSDC ---
dsk: $(PRGM).bin
	$(DECB) dskini $(PRGM).dsk
	$(DECB) copy -2 -b $(PRGM).bin $(PRGM).dsk,$(PRGM).BIN
	@echo "On CoCo: Drive 0,\"/$(PRGM).dsk\" : LOADM\"$(PRGM)\" : EXEC"

clean:
	rm -f *.bin *.dsk *.o *.lst *.i *.s *.link cshell smiley
