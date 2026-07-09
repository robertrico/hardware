# OS/2 Emulation Environment

A sequential, weekend-paced setup guide for exploring OS/2 1.x → 2.x → Warp on
86Box, oriented around Gordon Letwin's *Inside OS/2* (1988) and the
architectural ideas that make OS/2 historically interesting.

This layout mirrors `../ibm5150/` by design. `boot.sh` is the same pattern
with CD-ROM and larger-drive support; `library.sh` is copied verbatim (PCjs
has little OS/2-era material, but it's useful for DOS tools you'll want
alongside).

```
os2/
├── boot.sh         # Launch / create machines (adapted from ibm5150)
├── library.sh      # Search PCjs disk library → media/*.img
├── drives/         # Shared hard drive images
├── machines/       # 86Box VM configs (one dir per machine)
├── media/
│   ├── os2/        # OS/2 install floppies + ISOs
│   ├── dev/        # Compilers, assemblers, debuggers, toolkits
│   ├── drivers/    # Video / network / mouse drivers
│   └── tools/      # Kermit, file utilities, editors
├── software/       # Original archives (zips) — kept for provenance
└── tools/          # Host-side helpers (pcbox lives in ibm5150)
```

---

## How this guide is structured

Six stages, each a clean stopping point:

1. **Pick your era & machine profile** (read first — don't skip)
2. **Install OS/2 1.21** (Letwin-era, Microsoft co-development)
3. **Build a 1.x toolchain** (MS C 6.00a, MASM 5.1, CodeView, IBM Toolkit)
4. **First programs** (CLI, DLL, threads, PM)
5. **Install OS/2 2.1 and Warp 3** (32-bit shift, Workplace Shell)
6. **2.x / Warp toolchain** (C Set/2 or Open Watcom, Developer's Toolkit)

Each stage ends with an explicit **CHECKPOINT** you can run to confirm the
previous stage works before committing more time.

> **Host note:** These instructions assume macOS (as used in `ibm5150/`).
> Linux works identically — only the 86Box path and `screencapture`
> references change. Everything host-side is plain bash + `mtools`.

> **Time budget:** Stages 1-4 are a weekend (~12-16 hours real time, most
> of it waiting on floppy swaps and compile). Stage 5-6 is a second
> weekend. Don't try to do Warp-era work before getting 1.x comfortable —
> the architectural ideas compound.

> **What the user said to assume:** you already know 86Box basics (have
> ROMs installed, know the right-click-titlebar → Media menu), know DOS
> and assembly, are on Linux or macOS host, have vintage computing
> experience but haven't done OS/2 specifically.

---

# Stage 0 — Prerequisites

```bash
# 86Box
brew install 86box            # or dmg from 86box.net
# The ROM set is NOT included — grab the community ROM pack.
# Verify you have the machines we need:
ls ~/Library/Application\ Support/net.86box.86Box/roms/machines/ \
   | grep -E '^(ibmat|ibmps2_m50|ibmps2_m70_type4|valuepoint433)$'

# Host-side tools
brew install mtools           # mcopy/mdir against FAT floppy images
brew install cdrtools         # mkisofs — build install ISOs from directories
brew install p7zip            # unpack WinWorld archives (often .7z)
```

**CHECKPOINT 0:** `./boot.sh` should list no machines, no drives, no media,
and print no errors. If it errors, you probably don't have 86Box at
`/Applications/86Box.app`.

---

# Stage 1 — Machine profiles

OS/2 is picky about hardware in ways DOS isn't. The *right* machine for
your era saves hours. Here are three profiles covering the three
historically interesting moments.

All three are shipped pre-configured as **maxed-out dev machines** — the
OS/2 counterpart to `ibm5150/xt_max`. Drives are already created and
symlinked. First launch, open settings once with `-s` to let 86Box
normalize any keys it may prefer differently, then save.

## Profile A — `at_max` (1.x, Letwin-era Microsoft OS/2)

**Target:** OS/2 1.0 through 1.3, Standard Edition (the version Letwin
documents). IBM PC AT-class. ISA, not MCA — deliberately, so you can
install with fewer reference-disk headaches.

| Setting       | Value                                       |
|---------------|---------------------------------------------|
| Machine       | `ibmat` (IBM PC AT, 1984)                   |
| CPU           | 80286 @ 12 MHz                              |
| FPU           | 80287                                       |
| RAM           | 8192 KB (8 MB — plenty for 1.x + PM)        |
| Video         | ET4000 VGA (broad 1.x driver support)       |
| Sound         | Sound Blaster 2.0 (period-appropriate)      |
| Network       | NE2000 ISA + SLiRP (for MTCP / TCP/IP later)|
| HDD           | 2× 41 MB MFM (C: + D:) — system + source    |
| HDD ctrlr     | `st506_xt` (MFM)                            |
| FDD 1         | 5.25" 1.2 MB (install media)                |
| FDD 2         | 3.5" 1.44 MB (tools & transfer)             |
| Mouse         | Microsoft Serial on COM1 (required for PM)  |
| Ports         | COM1, COM2, LPT1                            |
| RTC           | Generic MM58167 (same as `ibm5150` machines)|

**Why:** OS/2 1.x targets the 286, runs in its protected mode. The whole
point of *Inside OS/2* is how segmented protected mode shapes the API —
you want a machine that actually boots in 286 mode, not a 386 pretending.
ISA + generic hardware = far fewer install-time surprises than MCA. The
dual-drive layout (C: for OS/2 + toolchains, D: for source) mirrors the
`xt_max` pattern and gives you a clean rebuild target if anything goes
sideways — `FORMAT D:` is cheap.

## Profile B — `ps2m70_max` (2.x, IBM 32-bit, MCA-authentic)

**Target:** OS/2 2.0 and 2.1 — first true 32-bit OS/2, introducing
Workplace Shell, MVDMs, and flat memory. Doing this on MCA is the period
experience IBM was pushing, and 86Box supports the PS/2 M70 reference
disk well.

| Setting       | Value                                         |
|---------------|-----------------------------------------------|
| Machine       | `ibmps2_m70_type4` (PS/2 Model 70, 386DX)     |
| CPU           | 386DX @ 25 MHz                                |
| FPU           | 387                                           |
| RAM           | 16384 KB (16 MB — M70 maximum; WPS loves it)  |
| Video         | Built-in VGA (MCA)                            |
| HDD           | ESDI 120 MB (hand-sized MFM-style geometry)   |
| HDD ctrlr     | Built-in ESDI                                 |
| FDD 1         | 3.5" 1.44 MB                                  |
| Mouse         | PS/2 (on-motherboard)                         |
| Ports         | COM1, LPT1 (built-in)                         |
| Network/Sound | Intentionally none — MCA adapters in 86Box are|
|               | spotty. Add via Stage 5 if you want them.     |
| Reference disk| Required — see Stage 5                        |

**Why MCA:** MCA's Programmable Option Select (POS) is a distinctly
OS/2-era idea — the machine's self-configuring bus is part of the story.
You'll need the Model 70 *reference disk* to configure the machine
before OS/2 will install.

**If you just want 2.x to work** and don't care about MCA: swap the
machine to `valuepoint433` (486DX2/66, ISA, IDE), give it 16 MB and a
200 MB IDE drive. Install is easier; you lose the POS/MCA texture.

## Profile C — `warp_max` (Warp 3 / 4, consumer peak)

**Target:** OS/2 Warp 3 "Red" or "Blue Spine," the 1994-96 consumer push.

| Setting       | Value                                        |
|---------------|----------------------------------------------|
| Machine       | `valuepoint433` (IBM ValuePoint 433DX)       |
| CPU           | 486DX2/66                                    |
| FPU           | built in                                     |
| RAM           | 32768 KB (32 MB — comfortable for Warp 4 too)|
| Video         | S3 Trio64 (Warp has a native driver)         |
| Sound         | Sound Blaster 16                             |
| Network       | NE2000 + SLiRP (Warp's TCP/IP stack talks)   |
| HDD           | IDE 500 MB                                   |
| FDD 1         | 3.5" 1.44 MB                                 |
| FDD 2         | 5.25" 1.2 MB (for any leftover 2.x installs) |
| CD-ROM        | ATAPI IDE (Warp comes on CD)                 |
| Ports         | COM1, COM2, LPT1, game                       |

**Why:** Warp is where OS/2 stops looking "tool vendor" and starts looking
like a real consumer OS with a browser and TCP/IP. The jump from 2.x to
Warp is less architectural than it is integration — worth seeing once.

---

## Tradeoffs summary

| Axis                      | 1.x (at_max)        | 2.x (ps2m70_max)    | Warp (warp_max)|
|---------------------------|---------------------|---------------------|----------------|
| Period accuracy           | high                | highest (MCA)       | high           |
| Install headache          | medium              | **high** (ref disk) | low (CD)       |
| Teaches segmented PM mode | **yes (the point)** | partially           | no             |
| Runs PM apps of its era   | yes                 | yes                 | yes            |
| Modern conveniences       | few                 | some                | many           |
| Toolchain variety         | MS-only era         | IBM / early Watcom  | Watcom / VAC++ |

**Recommendation:** Do A first (weekend 1). Skip to C if you want quick
wins, or do B for the MCA experience (weekend 2). Save Warp for last —
it's the least surprising and the most forgiving.

---

## 86Box-specific gotchas

- **MCA reference disks are mandatory for PS/2.** You can't skip this
  step the way you might on an ISA machine. The reference disk is a
  special bootable floppy; you'll boot it at least once before installing
  anything.
- **HDD geometry in 86Box:** if you create a drive manually (our
  `boot.sh new` does), 86Box computes geometry from the file size. MFM
  drives use 17 spt, so 60 MB ≈ 1024 cyl × 7 hd × 17 spt. For ESDI or
  IDE, let 86Box generate it from its settings UI — don't use raw `dd`
  unless you're sure.
- **VGA cards in MCA machines:** some ISA VGA cards won't show up in
  Model 70/80. The built-in on-motherboard VGA *is* the right answer.
- **1.x mouse:** must be set up *before* installing PM, or you'll be
  stuck in a point-and-can't-click state. Configure Microsoft Serial
  mouse on COM1 at the settings stage. (2.x and Warp are fine with PS/2.)
- **Serial passthrough is unreliable** for automated OS/2 control —
  confirmed on the `ibm5150` side. Don't try to set up `pcbox`-style
  driving for OS/2 without expecting to debug it. See "File transfer"
  below for the workflow I recommend instead.

---

# Stage 2 — Install OS/2 1.21

This is the Letwin-era install. Budget 2-3 hours, most of it sitting and
swapping floppies.

## 2.1 Acquire the install disks

OS/2 1.x was shipped as a bare OS and as "Extended Edition" (EE, with
Communications Manager and Database Manager). For learning, **Standard
Edition 1.21** is the sweet spot: Presentation Manager is fully present,
HPFS is there, the install is smaller.

Legitimate abandonware sources (these URLs may move — search the site if
they 404):

- **WinWorld**: `winworldpc.com/product/os-2-1x/121` — Microsoft OS/2 1.21
  and IBM OS/2 1.21 both listed.
- Prefer the **Microsoft branded** 1.21 if you want the Letwin experience
  (it literally says "Microsoft" on the boot screen). IBM's 1.21 is
  functionally equivalent.

Drop the downloaded `.img` files into `media/os2/`:

```
media/os2/
├── ms_os2_121_disk1.img       (install boot)
├── ms_os2_121_disk2.img
├── ...
└── ms_os2_121_disk7.img       (or however many)
```

File size should be 1,213,952 bytes (5.25 1.2MB) or 1,474,560 bytes (3.5"
1.44 MB) — if yours aren't exactly one of those, the image is wrong.

## 2.2 Verify the machine

```bash
cd /Users/hackbook/Development/hardware/vintage/os2
./boot.sh at_max -s          # opens 86Box settings for sanity check
```

`at_max` already has drives created (2× 41 MB MFM), symlinks in place,
and a starter `86box.cfg` with CPU/RAM/video/sound/network all set.
The `-s` pass lets 86Box normalize any fields it prefers differently
(it may silently rename keys between releases). On the settings screen,
verify and save:

1. **Machine** → `ibmat`, 286 @ 12 MHz, FPU 287, RAM 8192.
2. **Display** → `ET4000 AX` (or generic `VGA` if ET4000 isn't in your
   ROM set).
3. **Input devices** → Mouse: `Microsoft Systems Serial Mouse`
   (pre-set to `mssystems`).
4. **Ports** → Serial 1 & 2 ON, LPT1 ON.
5. **Sound** → `Sound Blaster 2.0`.
6. **Network** → `Novell NE2000` + SLiRP.
7. **Storage controllers** → HDC: `[MFM/RLL] IBM PC/XT Fixed Disk`
   (the `st506_xt` controller). FDC: AT built-in (`fdc_at`).
8. **Hard disks** → two entries, `drive_c.img` and `drive_d.img`,
   geometry `17 spt / 5 hd / 977 cyl` each.
9. **Floppy drives** → FDD 1: `5.25 1.2M`. FDD 2: `3.5 1.44M`.
10. Click OK — 86Box re-writes `86box.cfg` in its current canonical form.

If any of the above is missing or wrong in the settings UI (e.g.
ET4000 not listed for `ibmat`), just pick the nearest valid option and
save. The config in the repo is a starter, not a contract.

## 2.3 Boot the installer

```bash
./boot.sh at_max -a ms_os2_121_disk1.img
```

- Press a key at "Insert the OS/2 diskette..." prompt.
- At the language picker, choose English (or your preference).
- **Partition the disk.** The installer runs FDISK for you. Create one
  primary DOS/OS2 partition using all the space. Mark it active.
- Reboot when asked (Ctrl+Alt+Del; or Machine → Hard reset).

Swap floppies when the installer asks. In 86Box: right-click title bar →
**Media** → **Floppy drive 1** → **Select an image** → point at
`media/os2/ms_os2_121_disk2.img`, etc.

## 2.4 HPFS vs FAT decision

1.21 supports HPFS but is happy on FAT. Recommendation:

- **Install on FAT.** 1.x is small, FAT is stable, and it means you can
  mount the disk image with `mtools` from the host for file transfer.
- If you want to play with HPFS architecture (long names, extents), do
  it after the base install works — `CACHE.EXE` and `HPFS.IFS` can be
  enabled in `CONFIG.SYS` once you copy them over.

## 2.5 Expected install time

- OS/2 1.21 Standard Edition: ~20-40 minutes (mostly floppy swaps).
- Disk space on the VM: ~10 MB installed.

## 2.6 Post-install basics

First boot from C: drops you at a command prompt. You're in OS/2
protected mode. A few things to confirm:

```
[C:\] ver                        # prints "Operating System/2  Version 1.21"
[C:\] mem                        # shows extended memory available
[C:\] cmd                        # protected-mode command shell (you're already in it)
[C:\] start PMSHELL              # launch Presentation Manager
```

`PMSHELL` gets you the 1.x Desktop Manager / Task List + Program Manager-
like shell. This is the graphical half of Letwin's book come to life.

**CHECKPOINT 1:** You can boot to `[C:\]`, run `PMSHELL`, see the
Desktop, click Task List, quit back to CMD. If the mouse doesn't work,
return to 86Box settings and double-check the serial mouse config.

---

# Stage 3 — 1.x Toolchain

Goal: assemble and compile a native OS/2 1.x program — CLI and PM — and
debug it.

## 3.1 What to install and why

| Tool | Purpose | Source |
|------|---------|--------|
| **Microsoft C 6.00a** | Only widely-available period C compiler that emits OS/2 1.x NE binaries. Knows `/Lp` for protected-mode link. | WinWorld → Microsoft C 6.00 |
| **MASM 5.1** | Assembler that understands `.286P`, protected-mode segment attributes, and MS C's naming conventions. | WinWorld → MASM 5.x |
| **CodeView 4.x** | Source-level debugger. Native protected-mode version `CVP`. | Bundled with MS C 6.00. |
| **IBM OS/2 1.3 Developer's Toolkit** | Headers (`os2.h`, `pm.h`), .LIB import libraries, sample code. Works fine with 1.21. | WinWorld → IBM OS/2 Toolkit. Look for 1.3 version specifically. |
| **MS OS/2 SDK 1.21** | Alternative toolkit. Microsoft's branded version. Pick *one* toolkit; IBM's is more complete. | WinWorld |

**Licensing note:** all of these are explicitly listed on WinWorld as
abandonware. Treat them as archival reference.

## 3.2 Installing inside OS/2 1.21

The canonical path: write disk images to floppies (in 86Box's `Media`
menu), boot the VM, run installers.

For each tool package:

1. Drop the disk images in `media/dev/`. Suggested naming:
   `msc600_disk1.img`, ..., `masm51_disk1.img`, `codeview4_disk1.img`,
   `ibmtk13_disk1.img`, etc.
2. Mount disk 1 and boot:
   ```bash
   ./boot.sh at_max -a msc600_disk1.img
   ```
3. Inside OS/2:
   ```
   [C:\] A:
   [A:\] SETUP         # or INSTALL — depends on vendor
   ```
4. Follow prompts. Default install locations are sane — accept them
   (`C:\C600`, `C:\MASM`, `C:\TOOLKT13`).
5. Swap floppies as prompted via 86Box Media menu.

## 3.3 Set up environment

At the end, your `CONFIG.SYS` and environment need to know where these
tools live. Edit `C:\CONFIG.SYS` with the bundled editor (`E.EXE`), or
from a fresh CMD:

```
COPY C:\CONFIG.SYS C:\CONFIG.BAK
E C:\CONFIG.SYS
```

Add / extend these lines (adjust paths to what the installers chose):

```
LIBPATH=C:\OS2\DLL;C:\C600\LIB;C:\TOOLKT13\DLL
SET PATH=C:\OS2;C:\C600\BIN;C:\MASM\BIN;C:\TOOLKT13\BIN;C:\TOOLKT13\SAMPLES
SET LIB=C:\C600\LIB;C:\TOOLKT13\LIB
SET INCLUDE=C:\C600\INCLUDE;C:\C600\INCLUDE\SYS;C:\TOOLKT13\C\OS2H;C:\TOOLKT13\C
SET INIT=C:\C600\INIT
SET HELP=C:\OS2\HELP;C:\C600\HELP;C:\TOOLKT13\HELP
SET TMP=C:\TMP
```

(The `LIBPATH=` line is special to OS/2 — it's for DLL resolution at
load time. It's *not* inside a `SET`.)

Reboot. Confirm:

```
[C:\] CL                      # Microsoft C driver, no args = prints usage
[C:\] MASM                    # usage banner
[C:\] CVP                     # protected-mode CodeView
```

## 3.4 "Hello, protected world" — CLI

Create `C:\DEV\HELLO.C`:

```c
#define INCL_DOSPROCESS
#include <os2.h>
#include <stdio.h>

int main(void) {
    TID tid;
    DosGetPid((PPIDINFO)&tid);   /* note: API shape differs 1.x vs 2.x */
    printf("Hello from OS/2 process; my TID is %u\n", tid);
    return 0;
}
```

Build:

```
[C:\DEV] CL /Lp HELLO.C
```

`/Lp` tells CL to build for OS/2 protected mode (native). Without it you
get a DOS binary. The output is `HELLO.EXE`, an OS/2-flavored NE
executable.

```
[C:\DEV] HELLO
```

## 3.5 "Hello, Presentation Manager"

This is the payoff — a Win32-style `RegisterClass` / message-loop program,
predating Win32 by years. Create `C:\DEV\PMHELLO.C`:

```c
#define INCL_WIN
#define INCL_GPI
#include <os2.h>

MRESULT EXPENTRY WndProc(HWND hwnd, ULONG msg, MPARAM mp1, MPARAM mp2) {
    switch (msg) {
        case WM_PAINT: {
            HPS hps = WinBeginPaint(hwnd, (HPS)0, NULL);
            RECTL rc; WinQueryWindowRect(hwnd, &rc);
            WinFillRect(hps, &rc, CLR_BACKGROUND);
            WinDrawText(hps, -1, "Hello, Presentation Manager",
                        &rc, CLR_NEUTRAL, CLR_BACKGROUND,
                        DT_CENTER | DT_VCENTER | DT_TEXTATTRS);
            WinEndPaint(hps);
            return 0;
        }
    }
    return WinDefWindowProc(hwnd, msg, mp1, mp2);
}

int main(void) {
    HAB   hab   = WinInitialize(0);
    HMQ   hmq   = WinCreateMsgQueue(hab, 0);
    ULONG flags = FCF_TITLEBAR | FCF_SYSMENU | FCF_SIZEBORDER
                | FCF_MINMAX   | FCF_SHELLPOSITION | FCF_TASKLIST;
    HWND  hwndFrame, hwndClient;

    WinRegisterClass(hab, "PMHello", WndProc, CS_SIZEREDRAW, 0);
    hwndFrame = WinCreateStdWindow(HWND_DESKTOP, WS_VISIBLE, &flags,
                                   "PMHello", "PM Hello", 0, 0, 0,
                                   &hwndClient);

    QMSG qmsg;
    while (WinGetMsg(hab, &qmsg, 0, 0, 0))
        WinDispatchMsg(hab, &qmsg);

    WinDestroyWindow(hwndFrame);
    WinDestroyMsgQueue(hmq);
    WinTermInitialize(hab);
    return 0;
}
```

And `PMHELLO.DEF`:

```
NAME     PMHELLO WINDOWAPI
DESCRIPTION 'PM Hello World'
STACKSIZE 8192
```

Build:

```
[C:\DEV] CL /Lp /G2 PMHELLO.C PMHELLO.DEF
```

`/G2` generates 286 code. The linker consumes the `.DEF` automatically
when passed; or call `LINK PMHELLO.OBJ,,,OS2 PMWIN PMGPI,PMHELLO.DEF`
explicitly.

Run:

```
[C:\DEV] START PMHELLO
```

If PM isn't up, `START PMSHELL` first. You should see a resizable window
with centered text.

**Likely to waste hours if done wrong:**

- Forgetting `/Lp` → DOS binary, won't run or behaves weirdly.
- Wrong `.DEF` `NAME` type — `WINDOWAPI` is required for PM; CLI apps
  use `WINDOWCOMPAT` or no `NAME` line.
- `LIBPATH=` wrong → PM DLLs (`PMWIN.DLL` etc.) don't resolve; the
  program loads but crashes instantly.
- Missing `SET INCLUDE=` path to `OS2H` → `os2.h` not found.

## 3.6 Debugging with CodeView

```
[C:\DEV] CL /Lp /Zi /Od HELLO.C      # /Zi debug info, /Od no optimize
[C:\DEV] CVP HELLO.EXE
```

`CVP` is the protected-mode CodeView — it's a full-screen, source-level
debugger. F10 step, F8 step-into, F5 run, Ctrl-C break. Letwin used the
real-mode `CV`; `CVP` is the 286-era equivalent and what you want here.

**CHECKPOINT 2:** `HELLO.EXE` prints, `PMHELLO.EXE` draws a window, and
`CVP HELLO.EXE` single-steps through `main`. Commit here — you now have
a working Letwin-era toolchain.

---

# Stage 4 — Learning exercises

Five exercises, each small enough for an evening, each illuminating a
specific piece of Letwin's narrative. Do them on `at_max` (1.x). **I'll
describe what each exercise should teach and give API scaffolding — the
program itself is for you to write.** That's the whole point of the
book-paired exercise.

## 4.1 Segments and the LDT — "feel the 64K wall"

**Why it matters:** 286 protected mode has a 16-bit selector (the
"segment" register) pointing into an LDT/GDT. Each selector gives access
to up to 64 KB. Letwin's whole second chapter is about this. DOS
programmers reach for `near`/`far` and mostly don't think about it; in
protected mode, segment selectors are *objects* the OS hands you.

**Exercise:** Write a CLI program that:

1. Calls `DosAllocSeg(size, &selector, SEG_NONSHARED)` to allocate one
   segment ≥ 64 KB. Observe what happens.
2. Calls it multiple times for 60 KB chunks. Keep a linked list of
   selectors.
3. Fills each segment by walking `0:offset` within it.
4. Calls `DosFreeSeg(selector)`.

**Things to notice:**
- `DosAllocSeg` with `size > 64KB` fails with a specific error.
- Stepping off the end of a segment gives you a GP fault — actual
  protection, not "silent wrong data" like DOS.
- Compare mentally with `malloc()` on Linux: there, segments are
  invisible; here, they're front and center.

API reference: `DosAllocSeg`, `DosReallocSeg`, `DosFreeSeg`,
`DosGiveSeg`, `DosGetSeg`.

## 4.2 Threads and mutexes — "two producers, one printer"

**Why it matters:** OS/2 shipped with preemptive multithreading years
before Unix had pthreads or NT had thread APIs. The vocabulary (mutex
semaphore, event semaphore, muxwait) is Letwin's direct contribution,
and a lot of it reappears in Win32.

**Exercise:** Write a program that:

1. Creates 3 threads with `DosCreateThread`. Each thread prints its TID
   and a counter in a loop.
2. First version: no synchronization — watch the output interleave
   character by character.
3. Second version: add a mutex semaphore (`DosCreateSem` / `DosSemRequest`
   / `DosSemClear`). Protect the print with it. Output is clean.
4. Third version: use an event semaphore to have the main thread signal
   the workers to start simultaneously. `DosCreateSem` (with
   `CSEM_PRIVATE` flag for event-style), `DosSemSet`, `DosSemWait`,
   `DosSemClear`.

**Things to notice:**
- Threads share the process's segments. You don't need IPC for shared
  data.
- The 1.x sem API is clunkier than pthreads — Letwin's chapter on it
  explains why (the design is aimed at robust recovery from thread
  death).
- Preemptive scheduling: no cooperative yield needed.

API: `DosCreateThread`, `DosSuspendThread`, `DosResumeThread`,
`DosKillThread`, `DosCreateSem`, `DosOpenSem`, `DosCloseSem`,
`DosSemRequest`, `DosSemClear`, `DosSemSet`, `DosSemWait`,
`DosMuxSemWait`.

## 4.3 Dynamic Link Libraries — "the shape of the module loader"

**Why it matters:** OS/2 1.x DLLs are where the NE/LX module-loader
ideas that became Windows DLLs were first deployed in anger. The
"import library" → "run-time resolution" story is easier to see here
than anywhere else.

**Exercise:**

1. Write `GREETER.C` with one exported function `VOID Greet(PSZ name)`
   that prints "Hello, <name>" via `VioWrtCharStr` or `printf`.
2. Write `GREETER.DEF`:
   ```
   LIBRARY GREETER
   DESCRIPTION 'Greeter DLL'
   EXPORTS
       GREET  @1
   DATA SINGLE
   ```
3. Build it as a DLL:
   ```
   CL /Lp /Ge- /Alfu GREETER.C GREETER.DEF
   IMPLIB GREETER.LIB GREETER.DEF
   ```
4. Write a client that **links statically** against `GREETER.LIB`:
   ```
   CL /Lp MYAPP.C GREETER.LIB
   ```
5. Rewrite the client to **load dynamically**:
   ```c
   HMODULE hmod;
   PFN     pfn;
   DosLoadModule(NULL, 0, "GREETER", &hmod);
   DosGetProcAddr(hmod, "GREET", (PFN*)&pfn);
   pfn("world");
   DosFreeModule(hmod);
   ```

**Things to notice:**
- The DLL lives in `LIBPATH`, not `PATH`.
- Move `GREETER.DLL` out of the way mid-run: a statically linked client
  can't start; a dynamically linked one fails only at
  `DosLoadModule`-time. That's the tradeoff the loader exposes.
- OS/2 1.x has per-process *data segments* in DLLs (`DATA SINGLE` above
  makes it shared; switch to `DATA MULTIPLE NONSHARED` for per-process
  — and watch what changes).

## 4.4 IPC — "pipes are cheap, shared segments are scary"

**Why it matters:** Letwin devotes a whole chapter to IPC. OS/2 had
named pipes before Unix sockets were universal and before NT was built.
Comparing three IPC mechanisms in one afternoon shows why the designers
settled on what they did.

**Exercise:** Build the same "one server, one client, exchange N
messages" three times:

1. **Anonymous pipe** (parent/child): `DosMakePipe(&readH, &writeH,
   4096)`. Parent forks via `DosExecPgm(..., EXEC_ASYNC, ...)` passing
   the handle through `SET` in the child environment. Pipe becomes
   parent→child.
2. **Named pipe**: `DosMakeNmPipe("\\PIPE\\GREET", ...)` on the server,
   `DosOpen("\\PIPE\\GREET", ...)` on the client. Works across
   processes without a fork relationship.
3. **Shared memory**: `DosAllocSeg(size, &sel, SEG_GIVEABLE)` on the
   server, `DosGetSeg(sel)` on the client. Cooperate via a semaphore.

**Things to notice:**
- Anonymous pipes trade flexibility for simplicity.
- Named pipes are *paths* in a namespace — very Unix-like, years earlier.
- Shared segments are the fastest but require explicit synchronization
  and trust. The 2.x and NT designs keep them around but hide them.

## 4.5 A minimal PM message-loop — "why Windows looks like this"

**Why it matters:** The Presentation Manager message-loop is Win16/Win32's
direct ancestor. The call sequence (`WinInitialize` → `WinCreateMsgQueue`
→ `WinRegisterClass` → `WinCreateStdWindow` → `WinGetMsg` loop) is
nearly identical to the one every Petzold Win32 sample ever showed. You
already built the skeleton in 3.5; extend it.

**Exercise:** Starting from `PMHELLO.C`, add:

1. **A menu.** Hand-write a `.RC` resource file with a `MENU` block,
   compile with `RC.EXE`, bind into the `.EXE` with `RC PMHELLO.RES
   PMHELLO.EXE`. Handle `WM_COMMAND`.
2. **A timer.** `WinStartTimer(hab, hwnd, 1, 500)`. In `WM_TIMER` force
   a repaint and display a counter.
3. **Mouse tracking.** Handle `WM_MOUSEMOVE`, show the mouse position
   in the window title with `WinSetWindowText`.

**Things to notice:**
- There's no "callback register" — the message loop *is* the
  dispatching. Nothing happens without `WinDispatchMsg`.
- Coordinate origins in PM are bottom-left, unlike Windows (top-left).
  This is a genuine historical divergence worth feeling directly.
- PM has per-thread message queues. Spawn a second thread that tries to
  call `WinSetWindowText` on the main window and see what happens.

---

# Stage 5 — OS/2 2.x and Warp

Stages 2-4 are the core. If you've done them, you understand the
Letwin-era design. 2.x and Warp are about watching that design evolve
under IBM sole ownership.

## 5.1 OS/2 2.1 on the PS/2 Model 70

Acquire: WinWorld → **OS/2 2.1** (or 2.0 if you want the earlier WPS).

Extra step versus 1.x: **reference disks**.

1. Find the Model 70 reference disk: WinWorld has them under IBM PS/2
   reference diskettes, or archive.org. Drop into `media/os2/`.
2. Verify the machine:
   ```bash
   ./boot.sh ps2m70_max -s
   ```
   `ps2m70_max` is pre-configured (16 MB RAM, built-in VGA + ESDI).
   Just click through settings to let 86Box normalize the config and
   save.
3. First boot — **reference disk only**:
   ```bash
   ./boot.sh ps2m70_max -a ps2m70_refdisk.img
   ```
   The reference disk lets you: set system clock, configure adapters via
   POS, and most importantly, mark the HDD as bootable in the POS table.
   Do "Automatic Configuration," save, reboot.
4. Now install OS/2 2.1:
   ```bash
   ./boot.sh ps2m70_max -a os2_21_install_disk.img
   ```

2.1 install is longer (~60-90 minutes, 15-20 floppies). Choose:
- HPFS for C: (finally worth it at this scale).
- Install Workplace Shell (default).
- Skip Win-OS/2 on a first pass — you can add it later. It ~doubles
  install time.

## 5.2 Warp 3 on the valuepoint or generic

Warp comes on **CD**, which is a massive quality-of-life jump. Drop the
ISO in `media/os2/warp3.iso`.

```bash
./boot.sh warp_max -s   # confirm: valuepoint433, 32MB, S3 Trio64, IDE HDD, ATAPI CD
./boot.sh warp_max -a warp3_boot.img -c warp3.iso
```

The installer boots from the "installation diskette" and then pulls from
the CD. Net install time: ~45 minutes, no floppy swapping after the
first 2-3 disks.

**CHECKPOINT 3 (end of stage 5):** You've booted Workplace Shell on
both 2.1 and Warp. WPS dragging/dropping program objects is the best
"what was the idea of OS/2?" demo IBM ever shipped — spend 20 minutes
just clicking around.

## 5.3 The 32-bit toolchain

For 2.x and Warp, you have three realistic choices:

| Toolkit | Best for | Source | Tradeoffs |
|---|---|---|---|
| **IBM C Set/2** | 2.0/2.1 native | WinWorld | Period authentic. Slow compile. |
| **IBM VisualAge C++ 3.0** | Warp 3+ | WinWorld / archive.org | Huge install, but it's the Warp-era IDE. |
| **Open Watcom 2.0** (modern) | All of 2.x and Warp | github.com/open-watcom/open-watcom-v2 releases | **Recommended.** Open source, still maintained, produces genuine LX binaries, runs on 2.x host. |

**Recommendation:** Use **Open Watcom** for 2.x+ work. It's a modern
rebuild of the Watcom toolchain, released under an open source license,
hosts natively on OS/2 (there's an OS/2 installer), and produces
correct LX executables. You get period-authentic compilers without
period-authentic install pain.

Steps:

1. On the host, download the Open Watcom OS/2 installer (it's a ZIP of
   floppy images or a single large EXE depending on release).
2. Copy into the VM via a FAT floppy image or ISO (see file transfer
   below).
3. Run `setup.exe` inside OS/2. Install to `C:\WATCOM`.
4. Edit `CONFIG.SYS`:
   ```
   SET PATH=C:\WATCOM\BINP;C:\WATCOM\BINW;%PATH%
   SET INCLUDE=C:\WATCOM\H;C:\WATCOM\H\OS2
   SET LIB=C:\WATCOM\LIB386;C:\WATCOM\LIB386\OS2
   SET WATCOM=C:\WATCOM
   SET EDPATH=C:\WATCOM\EDDAT
   SET WIPFC=C:\WATCOM\WIPFC
   ```
5. Build a 32-bit OS/2 Hello:
   ```c
   #include <os2.h>
   int main(void) { printf("Hello from 32-bit OS/2\n"); return 0; }
   ```
   ```
   wcl386 -bt=os2v2 hello.c
   ```
6. Confirm it's LX, not NE: `EXEHDR HELLO.EXE` (if you have it) or just
   look at file size and behavior — LX runs only on 2.x+.

The **IBM Developer's Toolkit for OS/2 2.x** (separate from the
compiler) gives you the headers and `.H` files. It's worth installing
alongside Open Watcom if you want the IBM-branded samples; Open Watcom
ships enough headers for most work.

**CHECKPOINT 4 (end of stage 6):** `HELLO.EXE` built with Open Watcom
runs on 2.1. A minimal 32-bit PM app also runs (same skeleton as 1.x
but LX-flat instead of NE-segmented — contrast is the point).

---

# File transfer & workflow

This is where you'll spend more time than you expect, so nail it early.

## The three practical paths

### 1. Floppy images (works on everything)

For **FAT** partitions inside the guest, use `mtools` on the host to
write files into a floppy image, then mount it in 86Box:

```bash
# Make a blank 1.44 MB FAT floppy
dd if=/dev/zero of=media/tools/xfer.img bs=1024 count=1440
mformat -i media/tools/xfer.img -f 1440 ::
# Copy a file in
mcopy -i media/tools/xfer.img hello.c ::HELLO.C
# Boot with it
./boot.sh at_max -a xfer.img
# In OS/2:  COPY A:\HELLO.C C:\DEV\
```

Works on all three machines. Works regardless of FAT vs HPFS — the
*floppy* is FAT, the hard disk can be whatever.

### 2. ISO images (Warp + 2.x only)

For larger transfers (toolkits, Open Watcom), build an ISO:

```bash
mkdir /tmp/os2xfer
cp openwatcom-installer.exe my-src.zip /tmp/os2xfer/
mkisofs -o media/tools/xfer.iso -J -R /tmp/os2xfer/
./boot.sh warp_max -c xfer.iso
# In OS/2:  COPY G:\*.* C:\DEV\
```

OS/2 1.x has no CD-ROM support out of the box — use floppies there.

### 3. Direct image access (FAT partitions only)

If the guest VM is shut down and the hard disk is FAT, you can mount it
directly:

```bash
# Find partition offset in bytes (usually 8704 for first partition)
# On ibm5150/xt_max it's 8704 (17*512 sectors reserved).
mdir -i drives/at_max_c.img@@8704 ::
mcopy -i drives/at_max_c.img@@8704 hello.c ::DEV/HELLO.C
```

**Never** do this while 86Box has the image open. That's a fast road to
filesystem corruption.

For **HPFS** partitions (2.x and Warp if you chose HPFS): there's no
supported mtools equivalent. Use floppies or ISO instead.

## Host-side editor workflow

Recommended: edit on the host in your normal editor, sync into the VM
via floppy image. The cycle:

```
edit hello.c on host       (vim / VS Code / whatever)
mcopy -i xfer.img hello.c ::
in VM: COPY A:\HELLO.C .   (then CL /Lp HELLO.C)
```

Friction point: swapping floppy images in 86Box is a GUI click. For fast
iteration, either:

- Keep `xfer.img` as `fdd_01_fn` permanently and re-mount it after
  rewriting on the host. 86Box usually picks up the new content if you
  "Eject" then "Insert" via Media menu.
- Or bite the bullet and edit inside the guest with `E.EXE` (1.x
  system editor) or `EPM` (2.x+ enhanced editor — a surprisingly
  pleasant full-screen editor). Good once you're in a flow.

**Do not** try to set up serial-based automated transfer. The `ibm5150/`
workflow tried this with Kermit and hit reliability issues even on DOS.
OS/2's serial stack adds its own layer. Not worth the debugging.

## Version control

Keep source on the *host*. Treat the VM as a build/run environment. For
each exercise:

```
os2/
├── src/
│   ├── 4.1_segments/
│   │   ├── segs.c
│   │   └── segs.def
│   ├── 4.2_threads/
│   └── ...
└── ...
```

`git init` in `os2/`. Add `drives/*.img` and `media/*.img` to
`.gitignore` (they're huge and binary). The `.c`/`.asm`/`.def`/`.rc`
files are what you actually care about preserving.

---

# Quick-reference appendix

## OS/2 1.x "cheat sheet" (CLI)

```
E filename           system editor (small, modal)
START program        launch program async (equivalent to background)
DETACH program       launch as detached process (no window/console)
DIR /F               show attrs including hidden/system
SPOOL                print spooler control
MODE                 configure serial/LPT
HELPMSG SYS0002      explain an OS/2 error code
```

## Key Dos API families (1.x)

- `DosAllocSeg`, `DosFreeSeg`, `DosGiveSeg`, `DosGetSeg` — segments
- `DosCreateThread`, `DosSuspendThread`, `DosKillThread` — threads
- `DosCreateSem`, `DosSemRequest`, `DosSemClear`, `DosMuxSemWait` — sems
- `DosMakePipe`, `DosMakeNmPipe`, `DosConnectNmPipe` — pipes
- `DosOpen`, `DosRead`, `DosWrite`, `DosClose` — files
- `DosLoadModule`, `DosGetProcAddr`, `DosFreeModule` — DLLs
- `DosExecPgm` — spawn process

## 2.x / 32-bit API families

Same conceptual shape, different names. `DosAllocMem` replaces the
segment-oriented `DosAllocSeg` — watch this; it's the whole 32-bit story
in one rename. `DosCreateThread` becomes `DosCreateThread` (same name,
different signature). Semaphores split into Mutex/Event/MuxWait
primitives with their own `Dos*MuxSem` prefix.

## When the toolchain lies to you

- **"File not found" during link**: `LIB=` env var not set, or
  installer didn't update `CONFIG.SYS`. Check with `SET LIB`.
- **"SYS0002: File not found" running the binary**: a DLL listed in
  the binary's imports isn't on `LIBPATH`. Check with `LXLITE` or
  `EXEHDR` if you have it.
- **Program starts, paints nothing, exits**: `.DEF` file wrong. PM apps
  need `WINDOWAPI`; missing that, PM never adds them to the desktop
  task list.
- **GP fault on first memory access**: segment register points into
  an invalidated selector (usually because you freed a segment too
  early). Fire up `CVP` and inspect selectors with the `R` command.

## Sources to bookmark

- WinWorld — OS/2 images, MS C, MASM, IBM toolkits
- archive.org — IBM "Redbooks," reference diskettes, Developer Connection CDs
- github.com/open-watcom/open-watcom-v2 — modern Watcom
- edm2.com — OS/2 developer wiki; one of the most complete OS/2 API
  references still online
- `*.pdf` of Letwin's *Inside OS/2* — out of print, but archive.org
  has scans

---

# Suggested weekend schedule

**Weekend 1 (Letwin-era core):**

- Saturday morning: Stage 0 + 1 + 2. Get OS/2 1.21 booted.
- Saturday afternoon: Stage 3. Toolchain installed, `HELLO.EXE` works.
- Saturday evening: Exercise 4.1 (segments).
- Sunday morning: Exercise 4.2 (threads).
- Sunday afternoon: Exercise 4.3 (DLLs).
- Sunday evening: Exercise 4.5 (PM message loop).

**Weekend 2 (32-bit arc):**

- Stage 5 (OS/2 2.1 install + Warp install).
- Stage 6 (Open Watcom toolchain).
- Port Exercise 4.1 or 4.2 from 16-bit 1.x to 32-bit 2.x — the diff is
  the "what changed in 1992" story in source form.

Don't rush. The value is in reading the book alongside, not in ticking
boxes.
