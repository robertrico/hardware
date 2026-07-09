# From MS-DOS to Windows 2.x — A Period-Authentic 86Box Journey

A sequential guide for exploring the PC's transition from a text-mode OS into
a GUI platform, 1981–1988. The goal is to *feel* the pivot — what shipping
Windows 1.0 on a 256K 5150 actually meant, why it flopped, and what survived
into 3.x / 95 / NT.

This directory is **self-contained**. Its own `boot.sh`, `drives/`, `media/`,
`machines/`, `software/`. No dependencies on sibling directories. You can zip
it up and hand it to someone else and it works.

---

## How to use this

Four stages, pinned to reference machines and OS windows:

| Stage | Machine | Era | OS target | Emotional payload |
|-------|---------|-----|-----------|-------------------|
| 1 | `pc_5150` | 1981–1983 | PC-DOS 1.25 → 2.11 | *It's a business calculator with a keyboard* |
| 2 | `xt_5160` | 1983–1985 | PC-DOS 3.30 + Windows 1.04 | ★ *The GUI moment — cramped, tiled, twitchy, seminal* |
| 3 | `at_5170` | 1985–1988 | DOS 3.30/5.0 + Windows 2.03/2.11 + Excel 2.0 | *The wedge — why anyone bought Windows at all* |
| 4 | `deskpro_386` | 1986–1989 | DOS 3.30 + Windows/386 2.11 + Windows 3.0 | *The same era, maxed out — how fast could you make it?* |

Stages 1–3 are the sequential arc. **Stage 4 is the "beefy" contemporary
option** — same years, but on the flagship business PC of the era rather
than the baseline IBM reference. Run it in parallel with Stage 3 to feel
what the *expensive* 1987 machine was like.

Work stages 1→2→3 in order; drop into stage 4 whenever you want a
fast-machine check on the same software. Each stage is a day or two of
setup + a week of actually-using-it. Don't skip stage 1 — the
claustrophobia of DOS 1.x is the baseline against which everything else
is progress.

"You are here" markers are at each stage heading. Search for `★` to find
the Windows 1.0 moment specifically.

---

## Directory layout (self-contained)

```
msdos/
├── GUIDE.md            this document
├── boot.sh             launch script (copy of the ibm5150 tooling)
├── machines/           per-VM 86Box configs
│   ├── pc_5150/
│   ├── xt_5160/
│   ├── at_5170/
│   └── deskpro_386/
├── drives/             hard-disk images (shared, linked into machines/)
├── media/              floppy / CD images
│   ├── dos/
│   ├── windows/
│   ├── dev/
│   └── tools/
└── software/           source archives (.zip) as you collect them
```

`boot.sh` usage:

```bash
./boot.sh                      # list machines, drives, media
./boot.sh pc_5150              # boot a machine
./boot.sh pc_5150 -a floppy.img  # boot with floppy mounted
./boot.sh pc_5150 -s           # open 86Box settings without booting
./boot.sh new xt_5160          # create new machine with fresh 20MB drive
```

Requirements (host-side, one time):
- `brew install 86box mtools`
- 86Box ROMs at `~/Library/Application Support/net.86box.86Box/roms/`
- `mtools` for writing files into floppy images: `mcopy -i floppy.img
  myfile.c ::MYFILE.C`  (**do not** use serial/Kermit file transfer — it
  freezes 86Box; use floppy images via mtools).

---

# Stage 1 — IBM PC 5150 (1981–1983)

★ YOU ARE HERE: *5150, green screen, no hard disk, no subdirectories.*

The 5150 is the artifact. 16–256K RAM, two 5.25" floppies if you were flush,
MDA or CGA, cassette port you never used. The original 4.77 MHz 8088 and a
single-sided 160K floppy that held PC-DOS 1.00 in its entirety with room
left for WordStar.

## Machine config — `pc_5150`

Create it:

```bash
./boot.sh new pc_5150
```

Then edit `machines/pc_5150/86box.cfg`:

```ini
[Machine]
machine = ibmpc            ; IBM PC (1981) — verify exact ID in 86Box GUI
cpu_family = 8088
cpu_speed = 4772728        ; 4.77 MHz, the real clock
cpu_multi = 1
cpu_use_dynarec = 0
mem_size = 256             ; 256K — period appropriate max on-board

[Video]
gfxcard = mda              ; Monochrome Display Adapter — the text-mode original
                           ; Change to "cga" for color/games, "hercules" for
                           ; higher-res mono graphics (1982+)

[Input devices]
keyboard_type = keyboard_pc
mouse_type = none          ; no mouse on 5150 — don't fake it

[Storage controllers]
fdc = fdc_xt
hdc_1 = none               ; NO HARD DISK on original 5150. Two floppies only.

[Floppy and CD-ROM drives]
fdd_01_type = 525_1         ; 5.25" single-sided 160K — for DOS 1.00 authenticity
fdd_02_type = 525_1         ; upgrade to 525_2 (360K DSDD) for DOS 2.x+
```

**Why these choices:**
- MDA over CGA: authentic business-PC feel. CGA was the "games" card and its
  text mode was noticeably blurrier. MDA renders crisp 9×14 characters at
  720×350 — the PC's actual best-looking text mode until VGA.
- 256K: the max on the motherboard's third revision. 64K was the launch
  minimum. Going to 640K here is anachronistic — that's XT territory.
- No HDD: the original 5150 BIOS didn't support hard disks. If you want
  disk-based DOS, use Stage 2. Here, *live the two-floppy life.*
- `cpu_use_dynarec = 0`: on 8088-class machines keep the interpreter —
  closer to real timing. Dynarec is for 486+.

**Cramped vs comfortable:** Cramped. Deliberately. This is the machine that
taught the industry what "memory pressure" meant.

## Stage 1 OS install path

Install **two** DOS versions on this machine to feel the discontinuity:

### 1a. PC-DOS 1.25 (1982) — the "before" world

WinWorldPC → IBM PC DOS 1.25 (look for `PC DOS 1.10` or `1.25`; IBM called
1.10 what Microsoft called 1.25 internally — confusing but normal).

Drop floppy images into `media/dos/`. Boot straight from the
single-sided 160K floppy. No install procedure — DOS 1.x *is* the floppy.
`DIR` returns a flat list. There are no directories. `MD`, `CD`, `RD`
don't exist. Every file lives in the root. Copy a file with `COPY
A:THING.TXT B:`. No FAT16 — FAT12 throughout.

**Spend 30 minutes here.** Boot it, run DEBUG, type `d 0:0 L 20` to see
the interrupt vector table, `q` to quit, try `EDLIN` (the line editor —
yes, line at a time, numbered), and write a five-line batch file. Then
move on.

The pedagogical payload of DOS 1.x:
- **No subdirectories.** You feel why 2.0's Unix-borrowed hierarchical FS
  was an *event*.
- **160K, then 320K.** FAT12 originally supported 8-bit FAT entries (!) in
  DOS 1.0; 12-bit entries came with 1.10.
- **No installable device drivers.** Everything is baked into IO.SYS /
  MSDOS.SYS (or IBMBIO.COM / IBMDOS.COM on PC-DOS).
- **File handles via FCBs** (File Control Blocks — a CP/M holdover). By
  DOS 2.0 these get replaced with Unix-style file handles. You'll read
  old MASM code that still uses FCBs; now you know why it looks weird.

### 1b. PC-DOS 2.11 (1983) — the inflection

Download `PCDOS210.zip` or `MSDOS211.zip` from WinWorldPC into
`software/`, extract disk images into `media/dos/`. Install:

1. Boot with Disk 1: `./boot.sh pc_5150 -a pcdos211_disk1.img`
2. Insert formatted blank in B:, `DISKCOPY A: B:` (DOS 1.x style)
3. Or if you've added a hard disk to the VM (see below), `FDISK` →
   `FORMAT C: /S` → `COPY A:*.* C:\` → swap in disk 2 → repeat.

What DOS 2.0 brought (and 2.11 stabilized):
- **Hierarchical directories**. `MD`, `CD`, `RD`, the `\` path separator.
- **Installable device drivers** via `DEVICE=` in `CONFIG.SYS`. This is
  the seed that eventually grows into the Windows driver model.
- **I/O redirection and pipes**: `DIR | MORE`, `SORT < FILE.TXT`.
- **Environment variables** and the `PATH`.
- **Hard disk support** — the XT ships later this same year.

If you want hard disk on a 5150-style machine, either move to Stage 2, or
add an ST-506 controller to the 5150 config (historically this was a
Plus HardCard or Tallgrass — 86Box doesn't perfectly model those; easier
to just use the XT).

## Stage 1 exercise — `.COM` via DEBUG

The way a 1983 programmer would write their first program. No assembler
installed, no compiler. Just `DEBUG`.

```
A> DEBUG
-A 100
xxxx:0100 MOV AH,09
xxxx:0102 MOV DX,010E
xxxx:0105 INT 21
xxxx:0107 MOV AH,4C
xxxx:0109 INT 21
xxxx:010B DB 'Hello, 1983$'       ; actually use E or just more A lines
-R CX
CX 0000
:000F
-N HELLO.COM
-W
-Q
A> HELLO
```

The details matter: origin `100h` (DOS loads `.COM` files at offset
0x100, the 256 bytes before that are the PSP — Program Segment Prefix,
another CP/M inheritance), `$`-terminated strings (DOS function 09h),
`INT 21h` function `4Ch` to exit cleanly. This *is* the DOS programming
model.

**Rabbit hole worth it:** Read the PSP. `D CS:0 L 100`. You can see the
command-line tail, the environment segment pointer, FCBs pre-filled from
the command line. Understanding the PSP is understanding how DOS
programs *start*.

---

# Stage 2 — IBM PC XT 5160 (1983–1985) ★ The main event

★ YOU ARE HERE: *XT, 640K, 10MB hard disk, and Windows 1.0 on a floppy.*

This is the machine Windows 1.0 was designed around. An 8088 at 4.77 MHz,
640K RAM, a hard disk for the first time in mainstream PCs, and EGA
(1984) as the upgrade graphics card that actually made Windows bearable.

## Machine config — `xt_5160`

```bash
./boot.sh new xt_5160
```

Edit `machines/xt_5160/86box.cfg`:

```ini
[Machine]
machine = ibmxt86          ; IBM PC XT (1986 BIOS — stable, common)
cpu_family = 8088
cpu_speed = 4772728        ; keep it at 4.77 MHz for authenticity
cpu_multi = 1
cpu_use_dynarec = 0
mem_size = 640             ; 640K — the era's ceiling

[Video]
gfxcard = ega              ; EGA = the Windows 1.0 sweet spot (640x350, 16 colors)
                           ; Swap to "cga" (640x200 mono in Win) to feel why
                           ; the reviews were unkind.

[Input devices]
keyboard_type = keyboard_pc_xt
mouse_type = microsoft_bus  ; Microsoft Mouse (bus version, period-correct)
                            ; "serial_microsoft" also fine — needs a COM port

[Storage controllers]
fdc = fdc_xt
hdc_1 = st506_xt            ; Xebec-compatible — the XT's stock controller

[Hard disks]
hdd_01_fn = drive_c.img
hdd_01_mfm_channel = 0
hdd_01_parameters = 17, 4, 615, 0, mfm   ; 20MB MFM

[Floppy and CD-ROM drives]
fdd_01_type = 525_2         ; 5.25" 360K DSDD

[Ports (COM & LPT)]
serial1 = 1
lpt1 = 1
```

**Cramped vs comfortable:** Comfortable for 1985 software. Windows 1.0
will *run* but feel tight — Write + Paint open simultaneously will
thrash. That thrash is the experience. Don't bump RAM past 640K.

## Stage 2 OS install path

### 2a. PC-DOS 3.30 (1987) — actually, install this first

Yes, 3.30 technically postdates Windows 1.0 (1985). But 3.30 is the DOS
everyone actually ran under Windows 1.x in practice — it's the one that
had working hard-disk support, larger-than-32MB partitions (well, up to
32MB per partition with extended partitions for more), external command
set we remember (`XCOPY`, `APPEND`, `FASTOPEN`), and it ships on all the
XT clones sold into 1988.

If you want historical purity instead: DOS 2.11 (released with the XT)
then 3.20 (1986, first to support 3.5" 720K floppies and 1.2MB 5.25").

Install (standard DOS-era flow):

1. Boot disk 1: `./boot.sh xt_5160 -a pcdos330_disk1.img`
2. `A:\> FDISK` — create primary DOS partition, full disk, Y to use all
3. Ctrl+Alt+Del to reboot (still booting floppy)
4. `A:\> FORMAT C: /S` — Y to confirm; `/S` copies boot files
5. `A:\> COPY *.* C:\`
6. Right-click 86Box titlebar → Media → Floppy 1 → swap to disk 2
7. `A:\> COPY *.* C:\`
8. Eject floppy, reboot; now booting from `C>`
9. `COPY CON CONFIG.SYS` → `FILES=20` `BUFFERS=20` → F6 Enter
10. `COPY CON AUTOEXEC.BAT` → `@ECHO OFF` `PATH=C:\` `PROMPT $P$G` → F6 Enter

### 2b. Windows 1.04 (April 1987) ★

Windows 1.01 (Nov 1985) was the launch build. 1.03 fixed most of the
bugs. 1.04 added PS/2 + AT support and is the most stable. **Install
1.04** — it's Windows 1.x as Windows 1.x was meant to be.

Source: WinWorldPC → Windows 1.04 (5 floppies, ~1.5 MB total). Drop the
disks into `media/windows/`.

Install:

```bash
./boot.sh xt_5160 -a win104_setup.img
```

From DOS:

```
C:\> A:
A:\> SETUP
```

The setup prompts matter:
- **Hard disk install**: yes, `C:\WINDOWS`. (You can run from floppy —
  Windows 1.x was designed to. Don't. You'll hate it.)
- **Display adapter**: pick EGA (or CGA if you want the authentic lousy
  experience). Hercules is a fine choice too if you set `gfxcard =
  hercules`.
- **Pointing device**: Microsoft Mouse. Windows 1.x barely works without
  one — the tiled windows have no title bars to drag, so you *really*
  want a mouse for resize.
- **Keyboard**: IBM PC/XT.
- **Printer**: Generic/Text is fine, or the Epson FX-80 for 1985
  authenticity.

Swap floppies when prompted (right-click title bar → Media → Floppy 1 →
browse to `win104_disk2.img` etc.).

After install: `C:\> WIN` starts it.

**What you see:**
- MS-DOS Executive (the file manager — *Windows has no desktop yet*; the
  file manager IS the shell).
- Tiled windows. No overlap allowed except for dialogs and the popup
  menu. Apple's 1985 lawsuit threat made Microsoft swear off overlapping
  windows — and they stuck to that until Windows 2.0.
- Icons live at the bottom of the screen only when a window is
  minimized. This is the *iconic area*, not a desktop.
- The system font is a bitmap, not scalable. Forget anti-aliasing.

**Apps to actually try (in `C:\WINDOWS\`):**
- `PAINT.EXE` — the monochrome ancestor of Paintbrush. Era-appropriate
  polygon, brush, eraser, spray.
- `WRITE.EXE` — a WYSIWYG word processor. Mind-blowing for 1985 on a PC.
- `CARDFILE.EXE` — a Rolodex. You will realize this was a serious
  productivity app in its day.
- `CALENDAR.EXE` — day-view + month-view. Keyboard-heavy.
- `CALC.EXE` — standard + scientific calculator.
- `CLOCK.EXE` — the analog/digital clock. Pin it to a corner.
- `REVERSI.EXE` — the pack-in game. Play a round.
- `NOTEPAD.EXE` — plain-text editor. Yes, it was here from the start.
- `CLIPBRD.EXE` — the clipboard viewer. Cut-paste between apps was a
  *selling point* in 1985.
- `CONTROL.EXE` — Control Panel. Colors, mouse speed, date/time.
- `TERMINAL.EXE` — VT-52/VT-100/TTY. Dial a BBS.
- `PIF` files and `PIFEDIT.EXE` — Program Information Files let you run
  DOS apps from Windows with configured memory / graphics / keyboard
  settings. The proto-compatibility-shim.

**Spend serious time in MS-DOS Executive.** It is the UX that preceded
File Manager (3.0) and Explorer (95). It's also where you realize
Windows 1.x is halfway between a DOS shell and a GUI — you still
navigate in text directories, the menus are keyboard-first, and a lot of
"apps" are really DOS programs launched via PIF.

### Why Windows 1.x flopped (feel for yourself)

- **Tiled only.** Resize one window, the others auto-relayout. Maddening.
- **No overlapping except dialogs.** You can't glance between two
  documents by putting one *on top* of the other.
- **Cooperative multitasking in real mode.** An ill-behaved DOS app
  launched via PIF takes the whole system down. A well-behaved Windows
  app that doesn't yield takes the system down too.
- **64K segment everywhere.** The 8088's real-mode segment:offset
  addressing meant every allocation stared down the 64K cliff. Windows'
  memory manager (LocalAlloc, GlobalAlloc, MOVEABLE/DISCARDABLE handles)
  is the entire API trying to pretend 640K is bigger than it is.
- **No decent apps.** Microsoft's own Word was still DOS. Lotus was DOS.
  The first genuinely great Windows 1.x app was Aldus PageMaker 1.0
  (1987), and it arrived two years after launch.

### Bonus — what survived from 1.0

Look at what the 1.0 API shipped with that you can still use today:
- `HWND`, `HDC`, `WndProc`, `WM_PAINT`, `WM_CHAR`, `WM_LBUTTONDOWN`.
- `BeginPaint` / `EndPaint`.
- `GDI` — `TextOut`, `MoveTo`, `LineTo`, `Rectangle`, `Ellipse`.
- `GlobalAlloc` / `LocalAlloc`.
- The message loop: `GetMessage` → `TranslateMessage` → `DispatchMessage`.
- `PeekMessage` for games.
- `.RC` resource scripts, `.DEF` module definition files.

This is Win16. The shape of this API *is Windows*. It runs unchanged
through 3.0, 3.1, 95, 98, ME. NT renames it Win32 and widens pointers but
keeps the semantics. You are looking at the DNA.

## Stage 2 exercises

### Exercise 2.1 — A TSR (Terminate-and-Stay-Resident)

The peak DOS-era technique. Hook an interrupt vector, keep your code in
memory after exiting, get invoked on every timer tick or keypress.

The classic: a pop-up clock triggered by a hotkey. Minimum viable:

```asm
; CLOCK.ASM — tiny TSR that chimes on F12 via INT 16h hook
; Assemble: tasm clock.asm  ; link: tlink /t clock  (/t makes a .COM)
; (Or a86 clock.asm — A86 produces .COM directly.)
        .model tiny
        .code
        org 100h
start:  jmp install

old_int16 dd ?

new_int16 proc far
        pushf
        call [old_int16]        ; let the original handler read the key
        cmp ah, 58h              ; F12 scancode
        jne done
        ; your pop-up code here — print a string, read time, whatever
done:   iret
new_int16 endp

install:
        mov ax, 3516h            ; DOS get interrupt vector
        int 21h
        mov word ptr [old_int16], bx
        mov word ptr [old_int16+2], es
        mov ax, 2516h            ; DOS set interrupt vector
        lea dx, new_int16
        int 21h
        mov dx, offset install   ; keep everything up to 'install' resident
        shr dx, 4
        inc dx
        mov ax, 3100h            ; DOS: terminate and stay resident
        int 21h
        end start
```

Run `CLOCK`, then any DOS prompt or program — F12 fires your handler.
Feel the power and the fragility. A TSR bug hangs the machine.

This is how Borland Sidekick, the clearest precursor to "accessories,"
worked. The entire genre (pop-up calculators, notepads, dialers) ran on
this trick. Windows' WM_HOTKEY + system tray is the legitimized
descendant.

### Exercise 2.2 — Hello, Windows 1.0

You need: Microsoft C 3.0 or 4.0 + Windows 1.04 SDK. The SDK shipped
separately from Windows itself (~$500 in 1985).

Sources (WinWorldPC):
- Microsoft C 4.0 (1986) — fine; 3.0 is harder to find in working form
- Windows 1.0 Software Development Kit (1985)

The SDK contains:
- `WINDOWS.H` — the one true header
- `SLIBC.LIB`, `SLIBW.LIB` — small-model C runtime + Windows import lib
- `LINK4` — a Windows-aware linker (DOS LINK can't make NE executables)
- `RC.EXE` — resource compiler
- `SYMDEB` — symbolic debugger for Windows
- The docs as `.DOC` files (and a *very* thick printed manual you don't
  have unless you scanned it).

Minimal `HELLO.C`:

```c
#include <windows.h>

long FAR PASCAL WndProc(HWND, unsigned, WORD, LONG);

int PASCAL WinMain(HANDLE hInst, HANDLE hPrev, LPSTR cmdLine, int show)
{
    WNDCLASS wc;
    HWND hwnd;
    MSG msg;

    if (!hPrev) {
        wc.style         = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc   = WndProc;
        wc.cbClsExtra    = 0;
        wc.cbWndExtra    = 0;
        wc.hInstance     = hInst;
        wc.hIcon         = NULL;
        wc.hCursor       = LoadCursor(NULL, IDC_ARROW);
        wc.hbrBackground = GetStockObject(WHITE_BRUSH);
        wc.lpszMenuName  = NULL;
        wc.lpszClassName = "HelloClass";
        RegisterClass(&wc);
    }

    hwnd = CreateWindow("HelloClass", "Hello 1985",
                        WS_TILEDWINDOW,
                        0, 0, 0, 0,  /* Windows 1.x: size & pos ignored */
                        NULL, NULL, hInst, NULL);
    ShowWindow(hwnd, show);
    UpdateWindow(hwnd);

    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    return msg.wParam;
}

long FAR PASCAL WndProc(HWND hwnd, unsigned msg, WORD w, LONG l)
{
    PAINTSTRUCT ps;
    HDC hdc;

    switch (msg) {
    case WM_PAINT:
        hdc = BeginPaint(hwnd, &ps);
        TextOut(hdc, 10, 10, "Hello, Windows 1.0", 18);
        EndPaint(hwnd, &ps);
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hwnd, msg, w, l);
}
```

Plus a `.DEF` file (module definition — required for NE executables):

```
NAME         HELLO
DESCRIPTION  'Hello 1985'
EXETYPE      WINDOWS
STUB         'WINSTUB.EXE'
CODE         MOVEABLE
DATA         MOVEABLE MULTIPLE
HEAPSIZE     1024
STACKSIZE    5120
EXPORTS      WndProc @1
```

Build:

```
C:\> MSC -AS -Gsw -Oas -Zpe HELLO.C
C:\> LINK4 HELLO,HELLO,/MAP/LINE,SLIBW SLIBC/NOD,HELLO.DEF
C:\> RC HELLO.EXE
```

Flags worth knowing:
- `-AS` small memory model (64K code + 64K data — lived with this all
  the way through 3.1)
- `-Gsw` no stack checks, Windows entry/exit prologue
- `FAR PASCAL` calling convention — Pascal pushes args L→R and callee
  cleans up, smaller code; Windows API is Pascal calling convention
  clear through Win32.

**What this exercise teaches:** The message loop *is* Windows. The OS
doesn't call you; you call it to ask what happened. `WM_PAINT` is
demand-driven — the system tells you to repaint the dirty region; you
do it from scratch. This is the inverted-control abstraction that
separates GUI programming from DOS terminal programming. It is the
thing you learned, feels natural now, and wasn't the obvious choice in
1983.

### Exercise 2.3 — DOS direct-to-hardware vs Windows' GDI

Write two versions of "bouncing pixel":

**DOS version** — `BOUNCE.ASM`, uses CGA:

```asm
; Set mode 4 (CGA 320x200 4-color), write pixels directly to B800:0000
mov ax, 0004h
int 10h
; ... loop: write byte to ES:[DI] where ES=B800h and DI=y*80+x/4
```

Direct memory access. Screen tearing is your problem. Page flip? You'd
have to write it.

**Windows version** — `BOUNCE.EXE`, uses GDI:

```c
/* in WM_TIMER or PeekMessage idle loop: */
InvalidateRect(hwnd, &dirtyOld, TRUE);
InvalidateRect(hwnd, &dirtyNew, TRUE);
/* in WM_PAINT: */
Ellipse(hdc, x, y, x+10, y+10);
```

You *ask* for a repaint. The system *decides* when. You get clipping,
compositing with other windows, and device independence (CGA, EGA,
printer, plotter — same code) for free. You also get slow.

This contrast — direct hardware vs device-independent HAL — is the
architectural seed that echoes through every OS since. DOS's
performance comes from giving up isolation. Windows' flexibility comes
from inserting abstraction. Both tradeoffs are still being made in your
GPU driver today.

---

# Stage 3 — IBM PC AT 5170 (1985–1988)

★ YOU ARE HERE: *80286, 1 MB, EGA. Windows 2.x and the Excel wedge.*

The AT is where the personal computer grew up. 16-bit bus, 6 MHz (later
8), 1 MB RAM with the ability to run in protected mode (even though
almost nothing did for five more years). HIMEM.SYS arrives. Windows
2.0/286 uses it. Excel 2.0 bundles "run-time Windows." The wedge forms.

## Machine config — `at_5170`

```bash
./boot.sh new at_5170
```

```ini
[Machine]
machine = ibmat            ; IBM PC AT (1984)
cpu_family = 80286
cpu_speed = 8000000        ; 8 MHz — the later AT; 6 MHz for launch-spec
cpu_multi = 1
cpu_use_dynarec = 0
mem_size = 1024            ; 1 MB — 640K conventional + 384K extended

[Video]
gfxcard = ega              ; EGA is the Windows 2.x sweet spot
                           ; VGA (1987) also fine if you want post-286 vibe

[Input devices]
keyboard_type = keyboard_at
mouse_type = serial_microsoft

[Storage controllers]
fdc = fdc_at
hdc_1 = ide_isa            ; or st506_at for ST-506 MFM authenticity

[Hard disks]
hdd_01_fn = drive_c.img
hdd_01_ide_channel = 0
hdd_01_parameters = 40, 10, 977, 0, ide   ; 40 MB

[Floppy and CD-ROM drives]
fdd_01_type = 525_hd        ; 1.2 MB 5.25" HD (AT introduced this)
fdd_02_type = 35_2dd        ; 720K 3.5" (for PS/2-era software)

[Ports (COM & LPT)]
serial1 = 1
serial2 = 1
lpt1 = 1
```

**Cramped vs comfortable:** Comfortable. Windows 2.x wants ≥640K and
this has plenty. Excel 2.0 needs 512K + another 128K for files.

## Stage 3 OS install path

### 3a. PC-DOS 3.30 (again, or jump to MS-DOS 5.0)

3.30 is fine here too. If you want to see the DOS 5 memory management
story (HIMEM, EMM386, UMB, `MEM /C /P`, the `DEVICEHIGH=` and `LOADHIGH`
dance that defined 1991-era DOS), install MS-DOS 5.00 instead. Skip
4.01 — it was buggy enough that IBM's warranty department still has
PTSD.

### 3b. Windows 2.03 (Nov 1987) — first overlapping windows

After the Apple settlement was worked out (Microsoft got a license; the
wording later became the subject of the famous copyright suit Apple
lost in 1994), Microsoft shipped overlap.

Install from WinWorldPC → Windows 2.03. The setup is similar to 1.04
but now:
- Title bars are draggable.
- Windows overlap.
- Double-click opens. Single-click selects.
- The system menu (top-left) has Restore/Move/Size/Minimize/Maximize/Close.

Same apps (Write, Paint, Cardfile, Calendar, Clock, Reversi, Control
Panel, MS-DOS Executive). The shell is still MS-DOS Executive — no
Program Manager yet; that arrives in 3.0.

### 3c. Windows/286 2.11 (1988) — HIMEM-aware

The next step. Windows/286 uses HIMEM.SYS to move the BIOS and Windows
itself partially into the high memory area and extended memory. Not true
protected mode — it's a real-mode OS that cheats with segment tricks —
but your apps see more memory.

### 3d. ★ Excel 2.0 for Windows (1987) — the wedge

This is the exercise that rewrites your mental model. Install Excel 2.0
(WinWorldPC → Microsoft Excel 2.0 for Windows). It ships with **Windows
Runtime 2.0** bundled — a stripped-down Windows that boots just enough
to run Excel. Microsoft's gambit: you don't need to *buy* Windows, just
buy Excel, and Windows comes along. Lotus 1-2-3 had the spreadsheet
market locked; Microsoft couldn't sell Windows as a platform, so they
sold it as a peripheral to a killer app.

Feel that. Lotus refused to ship a Windows version until 1-2-3 for
Windows in 1991. By then Excel owned the market. The bundling strategy
worked so well it became the foundation of how Windows won the 1990s.

### 3e. (Trap) Windows 3.0 on the AT

You can install it. It runs. But 3.0's "real mode" support is a
retroactive feature for backwards compat; 3.0 really wants a 386 in
enhanced mode. That's exactly what Stage 4 is for.

## Stage 3 exercise — Run Windows 1.x app under Windows 2.x

Copy your `HELLO.EXE` from Stage 2 over to the AT (use `mcopy -i
media/windows/scratch.img HELLO.EXE ::HELLO.EXE` on the host, mount the
floppy, `COPY A:HELLO.EXE C:\`). Run it under Windows 2.x. It *mostly*
works — the NE executable format is the same, WndProc semantics are
the same. You will notice:

- Your window now has a title bar (Windows 2.x added it; your code
  didn't request it because in 1.x there wasn't one to request).
- `WS_TILEDWINDOW` in 1.x became `WS_OVERLAPPEDWINDOW` in 2.x (same
  value, renamed). Your app inherits overlapping-window behavior without
  a recompile.
- Menus look different but work.

This is the moment you realize Win16 compatibility was already an
explicit design goal by 1987. Microsoft kept this compatibility promise
for *thirty years*. Your HELLO.EXE from 1985, rebuilt against Win16, is
runnable on Windows 11 via NTVDM / WineVDM / similar. That's not an
accident; it's the business strategy encoded in the API.

---

# Stage 4 — Compaq Deskpro 386/20 (1986–1989) — The beefy contemporary

★ YOU ARE HERE: *20 MHz 386, 4 MB RAM, VGA. Windows/386 in V8086 mode.*

**The flagship business PC of the guide's era.** Compaq shocked IBM in
September 1986 by shipping the Deskpro 386 — the first PC based on the
80386 — six months before IBM's own 386 machines. This is the machine
that ended IBM's control over "what counts as a PC." By 1987–88 the
Deskpro 386/20 was the workstation every engineering and finance office
dreamed of having.

From here you'll experience the *same software* as Stages 2 and 3 but on
a machine that isn't fighting it. It's instructive to load Windows 1.04
on this and realize it feels fine — Windows 1.0 wasn't *bad software*,
it was *right-spec software on wrong-spec hardware.* Had every 1985 PC
been this fast, the story writes differently.

## Machine config — `deskpro_386`

```bash
./boot.sh new deskpro_386
```

Edit `machines/deskpro_386/86box.cfg`:

```ini
[Machine]
machine = deskpro386       ; Compaq Deskpro 386 (1986) — verify in 86Box GUI
cpu_family = i386dx
cpu_speed = 20000000       ; 20 MHz — the 386/20 variant
cpu_multi = 1
cpu_use_dynarec = 1        ; 386+ → safe to turn on dynarec
fpu_type = 80387           ; optional 387 coprocessor — for Excel, AutoCAD

mem_size = 4096            ; 4 MB — the flagship config in 1987-88
                           ; bump to 8192 (8 MB) for the "maxed out 1989" feel

[Video]
gfxcard = vga              ; VGA (1987) — the graphical killer feature
                           ; Compaq's actual card was proprietary "VGC"; stock
                           ; VGA is the closest 86Box will emulate.

[Input devices]
keyboard_type = keyboard_at
mouse_type = serial_microsoft

[Storage controllers]
fdc = fdc_at
hdc_1 = ide_isa            ; IDE — Compaq shipped ESDI historically, but IDE
                           ; is compatible and less cranky under 86Box

[Hard disks]
hdd_01_fn = drive_c.img
hdd_01_ide_channel = 0
hdd_01_parameters = 200, 16, 978, 0, ide   ; ~150 MB — period flagship
                                            ; (Deskpro 386 shipped 40–130 MB;
                                            ; clone upgrades went higher)

[Floppy and CD-ROM drives]
fdd_01_type = 525_hd        ; 1.2 MB 5.25" HD
fdd_02_type = 35_2hd        ; 1.44 MB 3.5" HD (arrived 1987)

[Ports (COM & LPT)]
serial1 = 1
serial2 = 1
lpt1 = 1
```

**Creating a bigger drive.** `boot.sh new` makes a 20 MB image by
default (fine for DOS 3.3). For a 386 flagship you want more room —
easiest path:

```bash
# After ./boot.sh new deskpro_386, resize the linked drive:
dd if=/dev/zero of=drives/deskpro_386.img bs=512 count=307440   # ~150MB
# Then adjust hdd_01_parameters in 86box.cfg to match.
```

Or edit the machine in 86Box's GUI: `./boot.sh deskpro_386 -s` and
recreate the hard disk there.

**86Box machine ID note.** 86Box's exact string for the Deskpro 386
varies by build (`deskpro386`, `compaq_portable3_386`, etc.). If
`deskpro386` doesn't resolve, open the settings GUI (`./boot.sh
deskpro_386 -s`), pick "Compaq Deskpro 386" from the Machine Type
dropdown, save. The config file will update with the canonical string
for your 86Box version.

**Alternative "beefy" options if you want IBM-branded:**

| Machine | 86Box machine= | Year | Notes |
|---------|----------------|------|-------|
| **Compaq Deskpro 386/20** | `deskpro386` | 1987 | Recommended — clone flagship, ISA bus |
| IBM PS/2 Model 70 | `ibmps2_m70_type3` | 1988 | IBM 386 in a desktop form factor; MCA bus |
| IBM PS/2 Model 80 | `ibmps2_m80` | 1987 | IBM's 386 tower flagship; MCA bus |
| Compaq Portable III 386 | `portableiii386` | 1987 | Luggable 386 — quirky; skip unless curious |

The MCA (Micro Channel Architecture) bus on PS/2s is an important
cultural detail — IBM tried to close the architecture and lost; nobody
made MCA cards, clones stayed ISA, clones won the market. For
*practical* software compatibility in 86Box, ISA (Deskpro) is the
simpler choice.

## Stage 4 OS install path

### 4a. PC-DOS 3.30 or MS-DOS 5.00

Either works. DOS 5 (1991) is technically post-era but it's the DOS you
want for the HIMEM/EMM386/UMB experience, and it was extremely common on
386 machines within a year of launch. If you install DOS 5, edit
`CONFIG.SYS`:

```
DEVICE=C:\DOS\HIMEM.SYS
DEVICE=C:\DOS\EMM386.EXE NOEMS
DOS=HIGH,UMB
FILES=40
BUFFERS=30
```

Then `MEM /C /P` shows your lower memory with drivers loaded into UMB
(upper memory blocks 640K–1MB). This is the memory-management song and
dance that defined a generation of `CONFIG.SYS` tweaking.

### 4b. Windows 2.11/386 (1988) — V8086 mode ★

This is the architecturally interesting install. Windows/386 2.11 is
the first Microsoft OS that uses the 386's **virtual 8086 mode** to run
*multiple DOS VMs in parallel*. Each "DOS box" is a separate virtual
machine; they can't crash each other. This is proto-Windows 95's VMM
(Virtual Machine Manager), five years early.

Install from WinWorldPC → Windows/386 2.11. After install, from
`C:\WINDOWS`:

```
C:\WINDOWS> WIN386
```

Open Cardfile, Calculator, and then Alt-Tab to a DOS window and run
`EDIT`. Realize you are running *multiple real-mode DOS applications in
separate virtualized 8086 environments, concurrently*, on software from
1988. The mental leap from Windows 2.03 (cooperative real-mode) to
Windows/386 (hardware-virtualized DOS VMs) is the biggest architectural
jump in the guide.

### 4c. Windows 3.0 (May 1990) — the breakthrough, in its native habitat

3.0 is out-of-scope chronologically (post-1988) but spiritually it
belongs on this machine: 3.0 was *designed* for the Deskpro 386-class
machine. Install it to feel why Windows finally won:

- **Program Manager** replaces MS-DOS Executive. Recognizable modern GUI.
- **File Manager** (Winfile) — the tree-view file browser.
- **386 Enhanced mode** — builds on Windows/386's V8086 work,
  fully-integrated.
- **VGA driver in 16 colors** at 640×480, or 256 colors at 320×200 in
  Solitaire.
- Runs your Stage 2 `HELLO.EXE` with no modifications.

Install then `WIN /3` (force enhanced mode). Play Solitaire. Play
Minesweeper. Install Excel 3.0. Feel how the 1987 Deskpro 386 becomes
the reference platform that Windows 3.0 targets. Historically, Windows
3.0 sold 10 million copies in its first two years and ended the Lotus
era.

**Out-of-scope trap:** Windows 3.1 (1992), multimedia PC, NT 3.1 —
these all belong to a different guide. Stop at 3.0 to keep this arc
coherent.

## Stage 4 exercise — Run a DOS program next to a Windows program

Under Windows/386 2.11:

1. Start Windows: `WIN386`
2. From MS-DOS Executive, double-click a `.PIF` for `WORDSTAR.EXE` or
   any DOS app you have installed.
3. Notice it runs in a DOS box *alongside* Calculator.
4. Alt-Tab between them.
5. Open a second DOS box with a different program.
6. Crash one of the DOS programs deliberately (`INT 19h` or just divide
   by zero in DEBUG). Notice the *other* DOS box and Windows itself are
   unaffected.

You've just experienced the reason Windows beat OS/2 and the Macintosh
to the desktop: **hardware-enforced process isolation on commodity PC
hardware, in 1988, on software that cost $99.** This is the moment the
mainframe-style multi-tasking OS became a consumer product.

Compare and contrast:
- DOS alone (Stage 1): one program, direct hardware access, no isolation.
- Windows 1.x (Stage 2): multiple programs, cooperative scheduler, shared
  memory — one crash kills all.
- Windows 2.x (Stage 3): same as 1.x plus overlap.
- Windows/386 (this stage): each DOS box is hardware-isolated; Windows
  apps still cooperative among themselves.
- Windows 95 (future): Windows apps themselves are preemptively
  scheduled in V86-aware VMs.
- Windows NT (future): true hardware-backed process isolation for
  everything; DOS is finally gone.

The whole arc is visible from the Deskpro.

---

# Development toolchain reference

By era, what to install, and what's actually tractable:

## DOS-era (1981–1987)

| Tool | Year | Source | Use |
|------|------|--------|-----|
| DEBUG | built-in | DOS | Writing tiny .COM programs; examining memory |
| EDLIN | built-in | DOS 1.x | Line editor (you'll hate it; that's the point) |
| MASM 1.00 | 1981 | WinWorldPC | Period-exact; buggier than 4 |
| MASM 4.00 | 1985 | WinWorldPC | The first "reasonable" MASM |
| MASM 5.10 | 1988 | WinWorldPC | The one you actually want to use |
| A86 | 1986 | shareware | Fast, single-file — the pragmatist's choice |
| TASM 1.0 | 1988 | WinWorldPC | Borland's competitor, ships with Turbo Debugger |
| LINK | built-in | DOS | The linker; you'll live with it |
| Microsoft C 3.0 | 1985 | WinWorldPC | The C for Windows 1.x SDK |
| Microsoft C 4.0 | 1986 | WinWorldPC | More stable; works with Win 1.x SDK |
| Microsoft C 5.1 | 1988 | WinWorldPC | Required for Windows 2.x SDK |
| Lattice C | 1983 | scarce | The C before MS-C; mostly a historical curio |
| Turbo Pascal 3.0 | 1985 | WinWorldPC | Single-pass, stupidly fast, iconic |
| Turbo Pascal 5.5 | 1989 | WinWorldPC | Object Pascal; the "real" TP |
| Turbo C 1.0 | 1987 | WinWorldPC | Turbo's answer to MS-C, IDE-first |
| Turbo C 2.0 | 1988 | WinWorldPC | Where you'd do serious DOS C in 1988 |

Drop source archives into `software/`, extracted floppy images into
`media/dev/`. Install on whichever machine fits the era: A86 + MASM 5.1
on `xt_5160` for Win 1.x SDK work; MASM 5.1 + MS-C 5.1 + Win 2.x SDK on
`at_5170` or `deskpro_386`.

**Honest assessment:**
- MASM 5.10 + LINK + DEBUG is a fine triangle for 8086/286 asm. Don't
  start with MASM 1.0 unless masochism.
- For Windows 1.x SDK programs, Microsoft C 4.0 is the most findable
  working combination. MS-C 3.0 works in theory; finding intact disks
  is the real problem.
- Turbo C 2.0 does not do Windows development (it's DOS-only until
  TC++ / Borland C++). For Windows work under Borland you need BC++
  2.0+, which is 386-era — install on `deskpro_386` if you care.
- The Windows SDK is a *huge* pain to set up correctly. Paths, LIB,
  INCLUDE all need configuring. Budget a day.

## Windows-era SDK specifics

Windows 1.0 SDK (1985) wants MS-C 3.00 or 4.00. Environment:

```
SET INCLUDE=C:\WSDK\INCLUDE
SET LIB=C:\WSDK\LIB
SET PATH=%PATH%;C:\MSC\BIN;C:\WSDK\BIN
```

Tools you'll use: `CL` (compiler driver), `LINK4` (NE linker), `RC`
(resource compiler), `SYMDEB` (debugger), `HEAPWALK` (heap visualizer
— diagnostic gold for memory issues).

Windows 2.x SDK similar but targets MS-C 5.10. Headers are larger.
`WINDOWS.H` picks up the overlapping-window constants.

**Trap to avoid:** the 5.25"-era SDK floppies are often corrupted in
online archives. If `LINK4` complains about "invalid object file" on
canonical code, assume bad disks and find another copy before debugging
your build.

---

# Cultural & historical context worth knowing while you're in there

## The apps that defined each era

**1981–1983 (5150 era):**
- **VisiCalc** — the killer app that sold Apple II's, ported to PC in
  1981. Killed by 1-2-3.
- **WordStar 3.0** — the word processor of choice. Ctrl-K diamond. It
  defined modal text editing on the PC.
- **dBASE II** — the database. `.CMD` scripts, `.DBF` files (still
  readable today). Every small business ran dBASE.

**1983–1985 (XT + early Windows):**
- **Lotus 1-2-3 1.0 / 1A / 2.0** — the spreadsheet *and* graphing *and*
  basic database. Integrated. Fast. Wrote directly to video memory,
  screw DOS portability. Killed VisiCalc, locked the business market
  for six years.
- **WordPerfect 4.2 (1986)** — WordStar's successor. `F7` to exit. The
  function-key reference card was printed on every secretary's wall.
- **Norton Utilities 1.0 (1982)** — disk editor, file recovery. *Peter
  Norton* was the Linus Torvalds of DOS.
- **Microsoft Word 1.0 for DOS (1983)** — existed, nobody cared;
  WordPerfect owned.

**1985–1988 (AT + Windows 2.x + Deskpro 386):**
- **Aldus PageMaker 1.0 for Windows (1987)** — the first genuinely
  great Windows app. DTP on the PC. Came out of the Mac scene
  (PageMaker 1.0 Mac was 1985). This is *why* Windows 2.x existed
  commercially.
- **Microsoft Excel 2.0 for Windows (1987)** — see Stage 3d.
- **AutoCAD R9 / R10 (1987/88)** — ran beautifully on the Deskpro 386
  with a 387. CAD was a 386-class workload from its earliest days.
- **Microsoft Flight Simulator 3.0 (1988)** — the graphics benchmark
  of the era.
- **WordPerfect 5.0 (1988)** — still DOS; PostScript support; the peak
  before the Windows transition killed them.

## Why Windows 1.0 took so long

- **Announced Nov 1983**, shipped **Nov 1985**. Two solid years of
  vaporware. InfoWorld's "Golden Vaporware" award, 1984.
- **Reasons:**
  - 8086 segment hell. The memory manager went through several
    rewrites. MOVEABLE/DISCARDABLE handles were invented here.
  - The device-independent graphics layer (GDI) was new. Display
    drivers for every weird card (CGA, EGA, Hercules, Tandy, half a
    dozen PC clones) had to be written and tested.
  - Apple's 1983 lawsuit threat. Microsoft licensed Mac UI elements
    from Apple in Nov 1985 (right before shipping) with language scoped
    to Windows 1.0. Microsoft later argued — successfully, in 1994 —
    that future versions were covered. That license is why Windows has
    title bars, scrollbars that look like Mac scrollbars, and the
    pull-down menu bar.
  - IBM's complicated relationship with Microsoft over what would
    become OS/2 — Windows 1.0 was not IBM's strategic direction. IBM
    preferred TopView (shipped 1985, died fast).
  - Hardware. Windows 1.0 *targeted* the XT but was unbearable without
    512K+ RAM; most machines shipped with less.

## The DOS "beginning of the end" you can feel in Windows 1.x

- **Segmented memory is a dead end** — the 286 protected mode was the
  future; Windows 1.x is the last major Microsoft OS fully committed
  to real-mode segmentation.
- **Installable drivers are a ratchet** — once CONFIG.SYS accepts
  DEVICE= lines, the OS is no longer a fixed target. Driver vendors
  own pieces of it. Windows takes this to its logical extreme (the
  GDI driver, the comm driver, the keyboard driver).
- **The shell is becoming software** — DOS's COMMAND.COM is a thin
  layer on a fixed set of built-ins. MS-DOS Executive shows that the
  shell is just another program. Program Manager (3.0) and Explorer
  (95) are the same idea fully realized.
- **The API is an abstraction, not a call-gate** — DOS programs talk
  to INT 21h. Windows programs talk to `user.exe`, `kernel.exe`,
  `gdi.exe` via dynamic linking. DLL dependency graphs are literally
  the Windows 1.0 innovation that made Windows a platform instead of
  an OS.

Spending an afternoon looking at `USER.EXE`, `KERNEL.EXE`, `GDI.EXE` in
the `WINDOWS\` directory — they're on the floppy, open them in a hex
editor, look at the NE header — is more architecturally useful than
most books on OS design.

---

# Rabbit holes vs traps

## Worth going down

- **PSP and FCB internals** (Stage 1). Teaches the CP/M → DOS transition.
- **TSRs** (Stage 2, exercise 2.1). Teaches interrupt-driven
  programming; the mental model for signal handlers and ISRs.
- **The Windows 1.x message loop** (Stage 2, exercise 2.2). The DNA.
- **Excel 2.0 + runtime Windows bundling** (Stage 3d). The most
  important business decision in PC history, and you can literally
  install it.
- **V8086 mode in Windows/386** (Stage 4, exercise). The
  architectural leap that made Windows 95 possible.
- **NE executable format**. Read the header with a hex editor. `MZ`
  DOS stub + `NE` Windows header. The format shipped 1985 and was
  used unchanged through Windows 3.11 in 1993.

## Traps (will eat a weekend)

- **MS-DOS 1.00 vs 1.25 vs PC-DOS 1.00 vs 1.10** — the versioning is
  a mess. Pick one, move on.
- **Hercules graphics in Windows 1.x** — the driver is weirdly flaky;
  stick to EGA or CGA.
- **TopView / DESQview / GEM** — all real alternate worlds, all
  interesting, all massive sidetracks. GEM especially (used by Atari
  ST) is tempting. Budget *nothing* for these unless you commit a
  week.
- **Windows 1.0 printer drivers**. Just use Generic/Text. Do not try
  to get an emulated LaserJet working.
- **MASM macro wizardry**. MASM's macro language is
  Turing-tarpit-adjacent. You can get sucked in for days. Write
  straight-line asm; refactor later.
- **PS/2 Micro Channel adapters in 86Box**. The MCA bus is historically
  interesting but card support in the emulator is spotty. Stick to the
  Deskpro (ISA) for the beefy machine.
- **Serial/Kermit-based file transfer into 86Box**. Freezes the
  emulator. Use `mtools` on the host to write floppy images and mount
  them.

## Sourcing images — one-line directory

- **WinWorldPC** (winworldpc.com) — the canonical archive for
  abandoned Microsoft/IBM/Borland software. DOS 1.x–6.22, Windows
  1.01–3.11, SDKs, MS-C, MASM, Turbo C, Turbo Pascal, Lotus,
  WordPerfect, dBASE.
- **PCjs Machines** (pcjs.org/software/pcx86) — pre-built bootable
  disk images. Good for DOS versions when WinWorld files are corrupted.
- **BetaArchive** — older Windows SDK builds and odd intermediate
  versions. Requires account.
- **Internet Archive** — grab bags; quality varies.

---

# Suggested work order (one-paragraph TL;DR)

1. Create `pc_5150`. Boot PC-DOS 1.25 from a single floppy. Wander in
   DEBUG for 30 minutes. Install PC-DOS 2.11. Feel the subdirectory
   discontinuity. Stage 1 done. (1 afternoon.)
2. Create `xt_5160`. Install PC-DOS 3.30 to hard disk. Install Windows
   1.04 with EGA + mouse. Spend real time in MS-DOS Executive. Open
   Write, Paint, Cardfile, Calendar simultaneously and feel the tile
   shuffle. Play Reversi. Try CGA briefly to feel the before. (1
   weekend.)
3. Install MS-C 4.0 + Windows 1.0 SDK on `xt_5160`. Build HELLO.EXE.
   Step through with SYMDEB. Feel the message loop. (1 weekend — the
   SDK setup takes a day.)
4. Write a TSR on `xt_5160`. F12-triggered popup clock. Understand
   INT 21h 31h (TSR) and INT 21h 25h (set vector). (1 afternoon.)
5. Create `at_5170`. Install DOS 3.30 + Windows 2.03. Copy HELLO.EXE
   across; run under 2.x; notice the overlapping window came free.
   (1 afternoon.)
6. Install Excel 2.0 for Windows on `at_5170`. Marvel at the runtime
   Windows bundling. Build a spreadsheet. Understand the wedge. (1
   afternoon.)
7. Create `deskpro_386`. Install DOS 3.30 or 5.0 + Windows/386 2.11.
   Run multiple DOS boxes in parallel via V8086 mode. Install Windows
   3.0 to see 386-enhanced mode as its native habitat. (1 weekend.)

Total: 3 weekends of focused work to complete the arc. Another
indefinite amount of time if you let the rabbit holes pull you.

---

# Appendix — 86Box machine ID cheat sheet

Verify these in the 86Box GUI ("Machine type" dropdown) — the IDs here
are what I know; the exact strings sometimes drift between 86Box
releases.

| IBM / clone model | 86Box `machine=` | Notes |
|-------------------|-------------------|-------|
| PC 5150 (1981) | `ibmpc` | Original BIOS |
| PC 5150 (1982) | `ibmpc82` | Later BIOS revision |
| PC XT 5160 (1982) | `ibmxt` | Original XT |
| PC XT 5160 (1986) | `ibmxt86` | Last XT BIOS; 640K on-board; use this |
| PCjr | `ibmpcjr` | Don't — tangent |
| PC AT 5170 (1984) | `ibmat` | 6 MHz 286 |
| PC AT 5170 (1986) | `ibmat_type3` | 8 MHz 286, later BIOS |
| Compaq Deskpro 386 | `deskpro386` | 16/20 MHz 386, ISA, 1987 flagship |
| Compaq Portable III 386 | `portableiii386` | Luggable 386, 1987 |
| PS/2 Model 30 | `ibmps2_m30` | 8086 + VGA; interesting later |
| PS/2 Model 50 | `ibmps2_m50` | 286 + MCA; OS/2-era |
| PS/2 Model 70 | `ibmps2_m70_type3` | 386 + MCA desktop |
| PS/2 Model 80 | `ibmps2_m80` | 386 + MCA tower, IBM flagship |

Graphics cards that matter for this era:

| Card | `gfxcard=` | Era | Notes |
|------|------------|-----|-------|
| MDA | `mda` | 1981+ | Best-looking 80x25 text, no graphics |
| CGA | `cga` | 1981+ | Color, graphics, blurry text |
| Hercules | `hercules` | 1982+ | Mono graphics at 720x348 |
| EGA | `ega` | 1984+ | The Windows 1.x/2.x sweet spot |
| VGA | `vga` | 1987+ | Windows 3.x territory; Deskpro 386 flagship |

---

*The point of this exercise is not nostalgia. It is to see where the
abstractions come from. Every time you write `hwnd`, every time you
hear "message pump," every time Win32 does something weird that only
makes sense if you remember 64K segments — you will, from now on,
remember them.*
