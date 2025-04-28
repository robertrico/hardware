# OTA Bootloader with Custom Memory Mapping

## Update
This is no working. RAM is getting clobbered and we need to restore .bss and .data .rodata and probably aeabi functions too. It's just, not the tool for this.

This project demonstrates how to use linker files to create custom memory mappings for enabling a partitioned bootloader application with Over-The-Air (OTA) update functionality. Inspired by the work in [pico_fota_bootloader](https://github.com/JZimnol/pico_fota_bootloader) and [Hunter-Adams-RP2040-Demos](https://github.com/vha3/Hunter-Adams-RP2040-Demos/tree/master/Bootloaders), this approach allows seamless firmware updates while maintaining a robust bootloader.

## Key Features
- **Custom Memory Mapping**: Linker scripts define separate memory regions for the bootloader and application firmware.
- **Partitioned Bootloader**: The bootloader resides in a dedicated memory space, ensuring it remains intact during OTA updates.
- **OTA Functionality**: Enables remote firmware updates without requiring physical access to the device.

## How It Works
1. **Linker Files**: Custom `.ld` linker scripts are used to partition the flash memory into distinct regions for the bootloader and application.
2. **Bootloader**: The bootloader is responsible for verifying and loading the application firmware.
3. **OTA Updates**: The application firmware can download and store new firmware images, which the bootloader will validate and apply on the next boot.

## Getting Started
1. Clone this repository.
2. Review and modify the provided linker files to suit your hardware's memory layout.
3. Build the bootloader and application firmware using the custom linker scripts.
4. Flash the bootloader to your device and deploy the application firmware.

## References
- [pico_fota_bootloader](https://github.com/JZimnol/pico_fota_bootloader)
- [Hunter-Adams-RP2040-Demos](https://github.com/vha3/Hunter-Adams-RP2040-Demos/tree/master/Bootloaders)

## License
This project is open-source and available under the MIT License.