# AS9 Modernization for Apple Silicon (M3 Mac)

This document describes the changes made to modernize the AS9 6809 assembler from 2004 to compile and run on modern macOS with Apple Silicon.

## Original Problem

The original AS9 assembler was written in K&R C (pre-ANSI C style) and included a binary that would not run on Apple Silicon Macs. When attempting to compile from source, numerous errors occurred due to:

- K&R-style function declarations (deprecated and not supported in C23)
- Missing header includes
- Implicit `int` return types (not supported in ISO C99+)
- Missing function prototypes

## Build System

**Compiler Used:** GCC (compatible with Clang on macOS)
**Target Architecture:** ARM64 (Apple Silicon)
**Build Command:** `make`

## Changes Made

### 1. Header Additions

#### [as.c](as.c)
Added modern C standard library headers at the top:
```c
#include <stdlib.h>  // for exit()
#include <ctype.h>   // for tolower()
```

#### [ffwd.c](ffwd.c)
Added POSIX headers for file operations:
```c
#include <fcntl.h>   // for creat(), open(), O_* flags
#include <unistd.h>  // for read(), write(), close(), lseek()
```

### 2. Forward Function Declarations

Added comprehensive forward declarations in [as.c](as.c) to satisfy the compiler's requirement for function prototypes before use:

```c
/* Forward declarations */
char mapdn(char);
char *alloc(int);
char *skip_white(char *);
struct oper *mne_look(char *);
void initialize();
void re_init();
void open_files();
void make_pass();
int parse_line();
void process();
void fatal(char *);
void fwdinit();
void fwdreinit();
void localinit();
void stable(struct nlist *);
void cross(struct nlist *);
int install(char *, int);
struct nlist *lookup(char *);
void print_line();
void f_record();
void error(char *);
void warn(char *);
int delim(char);
void do_pseudo(int);
void do_op(int, int);
void emit(int);
int lobyte(int);
int hibyte(int);
int eval();
int set_mode();
void do_gen(int, int);
void eword(int);
void do_indexed(int);
void abd_index(int);
int rtype(int);
int regnum();
int any(char, char *);
int alpha(char);
int alphan(char);
int head(char *, char *);
void errors(char *, char *);
int get_term();
int is_op(char);
void fwdmark();
void fwdnext();
void hexout(int);
void binout(int);
```

### 3. K&R to ANSI C Function Conversions

Converted all K&R-style function definitions to ANSI C prototypes:

#### [as.c](as.c)
**Before:**
```c
main(argc,argv)
int     argc;
char    **argv;
{
```

**After:**
```c
int main(int argc, char **argv)
{
```

Similar conversions for:
- `initialize()` → `void initialize()`
- `re_init()` → `void re_init()`
- `open_files()` → `void open_files()`
- `make_pass()` → `void make_pass()`
- `parse_line()` → `int parse_line()`
- `process()` → `void process()`

#### [do9.c](do9.c)
- `localinit()` → `void localinit()`
- `do_op(opcode,class)` → `void do_op(int opcode, int class)`
- `do_gen(op,mode)` → `void do_gen(int op, int mode)`
- `do_indexed(op)` → `void do_indexed(int op)`
- `abd_index(pbyte)` → `void abd_index(int pbyte)`
- `rtype(r)` → `int rtype(int r)`
- `set_mode()` → `int set_mode()`
- `regnum()` → `int regnum()`

#### [util.c](util.c)
- `fatal(str)` → `void fatal(char *str)`
- `error(str)` → `void error(char *str)`
- `errors(char *msg, char *str)` → `void errors(char *msg, char *str)` (already modern)
- `warn(str)` → `void warn(char *str)`
- `delim(c)` → `int delim(char c)`
- `skip_white(ptr)` → `char *skip_white(char *ptr)`
- `eword(wd)` → `void eword(int wd)`
- `emit(byte)` → `void emit(int byte)`
- `hexout(byte)` → `void hexout(int byte)`
- `binout(byte)` → `void binout(int byte)`
- `print_line()` → `void print_line()`
- `any(c,str)` → `int any(char c, char *str)`
- `mapdn(c)` → `char mapdn(char c)`
- `lobyte(i)` → `int lobyte(int i)`
- `hibyte(i)` → `int hibyte(int i)`
- `alpha(c)` → `int alpha(char c)`
- `alphan(c)` → `int alphan(char c)`
- `white(c)` → `int white(char c)`
- `alloc(nbytes)` → `char *alloc(int nbytes)`

#### [symtab.c](symtab.c)
- `install(str,val)` → `int install(char *str, int val)` (fixed return type too)
- `lookup(name)` → `struct nlist *lookup(char *name)`
- `mne_look(str)` → `struct oper *mne_look(char *str)`

#### [eval.c](eval.c)
- `eval()` → `int eval()` (fixed return type)
- `is_op(c)` → `int is_op(char c)`
- `get_term()` → `int get_term()`

#### [pseudo.c](pseudo.c)
- `do_pseudo(op)` → `void do_pseudo(int op)`

#### [output.c](output.c)
- `stable(ptr)` → `void stable(struct nlist *ptr)`
- `cross(point)` → `void cross(struct nlist *point)`

#### [ffwd.c](ffwd.c)
- `fwdinit()` → `void fwdinit()`
- `fwdreinit()` → `void fwdreinit()`
- `fwdmark()` → `void fwdmark()`
- `fwdnext()` → `void fwdnext()`

### 4. Removed Obsolete Declarations

Removed obsolete local function declarations that conflicted with forward declarations:
- Removed `FILE *fopen();` declarations (now in `<stdio.h>`)
- Removed `char *malloc();` declaration (now in `<stdlib.h>`)
- Removed redundant local `struct oper *mne_look();` declarations
- Removed redundant local `char *skip_white();` declarations
- Removed redundant local `struct nlist *lookup();` declarations

### 5. Fixed Return Statement Issues

#### [util.c](util.c) - emit() function
Changed void function to not return a value:
```c
// Before:
if(Pass==1){
    Pc++;
    return(YES);
}

// After:
if(Pass==1){
    Pc++;
    return;
}
```

## Verification

After compilation, the resulting binary is:
- **File:** `as9`
- **Type:** Mach-O 64-bit executable arm64
- **Size:** ~74KB
- **Status:** ✅ Runs successfully on Apple Silicon

### Test Command
```bash
./as9 test.asm
```

### Sample Test Program
```asm
; Test 6809 assembly
        ORG     $0000
START   LDA     #$42
        STA     $1000
        BRA     START
        END
```

## Statistics

- **Files Modified:** 8 source files
- **Functions Converted:** ~40 K&R functions to ANSI C
- **Headers Added:** 4 includes
- **Forward Declarations Added:** ~40 function prototypes
- **Compilation Warnings:** 0 errors, 0 warnings (clean build)

## Backwards Compatibility

These changes maintain compatibility with the original AS9 functionality while bringing the code up to modern C standards. No assembly language syntax or behavior was changed - only the C implementation was modernized.

## Build Instructions

```bash
# Clean previous builds (if any)
make clean

# Build the assembler
make

# Test the assembler
./as9 your_file.asm
```

## Notes

- The original code used a unique compilation approach where all `.c` files are `#include`'d into [as9.c](as9.c), creating a single translation unit
- This approach still works but is unconventional by modern standards
- All function signatures now match between declaration and definition
- The code is now compatible with C99, C11, C17, and C23 standards

## Date of Modernization

October 19, 2025

## Original Source

AS9 6809 Cross-Assembler (circa 2004)
