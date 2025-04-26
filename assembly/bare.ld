ENTRY(_start)

MEMORY {
  FLASH(rx) : ORIGIN = 0x10000000, LENGTH = 2M
  RAM(rwx)  : ORIGIN = 0x20000000, LENGTH = 256K
}

SECTIONS {
  .vectors : {
    KEEP(*(.vectors))
  } > FLASH

  .text : {
    *(.text*)
  } > FLASH
}
