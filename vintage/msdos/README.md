# MS-DOS → Windows 2.x Exploration

Self-contained 86Box environment for exploring the PC's transition from
text-mode OS to GUI platform, 1981–1988.

See **[GUIDE.md](GUIDE.md)** for the full sequential walkthrough.

## Quick start

```bash
./boot.sh                       # list machines, drives, media
./boot.sh new pc_5150           # create a new machine (fresh 20MB drive)
./boot.sh pc_5150 -a disk1.img  # boot with floppy mounted
./boot.sh pc_5150 -s            # open 86Box settings
```

## Layout

```
msdos/
├── GUIDE.md            the walkthrough
├── boot.sh             launch script
├── machines/           per-VM 86Box configs
├── drives/             hard-disk images (shared, linked into machines/)
├── media/              floppy / CD images
│   ├── dos/            DOS install disks
│   ├── windows/        Windows 1.x / 2.x install disks
│   ├── dev/            MASM, MS-C, Turbo C, SDKs
│   └── tools/          utilities
└── software/           source archives (.zip) as collected
```

## Target machines

| Name | Machine | Era | Purpose |
|------|---------|-----|---------|
| `pc_5150` | IBM PC 5150 (1981) | 1981–1983 | PC-DOS 1.25 → 2.11 |
| `xt_5160` | IBM PC XT 5160 (1986 BIOS) | 1983–1985 | DOS 3.30 + Windows 1.04 ★ |
| `at_5170` | IBM PC AT 5170 (1984) | 1985–1988 | DOS 3.30/5.0 + Windows 2.x + Excel |
| `deskpro_386` | Compaq Deskpro 386/20 (1986) | 1986–1989 | The beefy contemporary — Windows/386, Windows 3.0 |

## Requirements (host)

```bash
brew install 86box mtools
```

86Box ROMs: `~/Library/Application Support/net.86box.86Box/roms/`

**File transfer into VMs:** use `mtools` to write files into floppy
images on the host, then mount. Do **not** use serial/Kermit — it
freezes 86Box.

```bash
mcopy -i media/dev/scratch.img myfile.c ::MYFILE.C
./boot.sh xt_5160 -a scratch.img
# then from DOS: COPY A:MYFILE.C C:\
```
