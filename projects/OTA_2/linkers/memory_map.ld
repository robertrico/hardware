/*
 * Copyright (c) 2025 Rob Rico
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/*
    +-------------------------------------------+  <-- __FLASH_START (0x10000000)
    |       Bootloader             (508k)       |
    +-------------------------------------------+  <-- __FLASH_SLOT
    |       Flash Application Slot (768k)       |
    +-------------------------------------------+  <-- __FLASH_DOWNLOAD_SLOT_START
    |       Flash Download Slot    (768k)       |
    +-------------------------------------------+  <-- __BOOTCONFIG
    |       Boot Config Slot       (4096)       |
    +-------------------------------------------+
*/

__XIP = 0x10000000;
__BOOTLOADER_LENGTH = 508 * 1024;
__FLASH_APPLICATION_LENGTH = 768 * 1024;
__FLASH_DOWNLOAD_LENGTH = __FLASH_APPLICATION_LENGTH;
__BOOT_CONFIG_LENGTH = 4096;

__FLASH_SLOT = __XIP + __BOOTLOADER_LENGTH;
__FLASH_DL_SLOT = __FLASH_SLOT+__FLASH_DOWNLOAD_LENGTH;
__MISC_FLASH = __FLASH_DL_SLOT;
__BOOT_SLOT = __XIP + (2048 * 1024) - 4096;

ASSERT(__FLASH_APPLICATION_LENGTH == ((2048 * 1024) - __BOOTLOADER_LENGTH - __BOOT_CONFIG_LENGTH) / 2,
      "__FLASH_DOWNLOAD_LENGTH has incorrect length");

ASSERT((__FLASH_DOWNLOAD_LENGTH%(4 * 1024)) == 0, "__FLASH_DOWNLOAD_LENGTH should be multiple of 4k");

ASSERT(2048k >= __BOOTLOADER_LENGTH + __BOOT_CONFIG_LENGTH + 2*__FLASH_DOWNLOAD_LENGTH,
      "Flash partitions defined incorrectly");