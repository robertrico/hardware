## Goal

1. Cross-compile and boot a minimal BusyBox-based Linux inside QEMU for local testing.
    
2. Cross-compile and boot BusyBox Linux on real Raspberry Pi 3 hardware.
    
3. Build a controllable, minimal embedded Linux system for future expansion.
    

---

## Phase 1: QEMU Setup

### Step 1: Install Required Packages

```bash
brew tap ArmMbed/homebrew-formulae
brew install arm-none-eabi-gcc
```

### Step 2: Fetch Prebuilt ARMv7 Linux Kernel (for QEMU)

```bash
wget https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/kernel-qemu-4.4.34-jessie -O zImage
```

### Step 3: Download and Build BusyBox

```bash
git clone https://busybox.net/git/busybox.git
cd busybox
make defconfig
make menuconfig
```

Inside `menuconfig`:

- Enable: `Settings -> Build BusyBox as a static binary (no shared libs)`
    
- Save and Exit.
    

Compile:

```bash
make -j$(sysctl -n hw.ncpu) ARCH=arm CROSS_COMPILE=arm-none-eabi-
make install
```

### Step 4: Create Root Filesystem

```bash
mkdir -p rootfs/{dev,proc,sys,etc,home,tmp,bin,sbin,usr/bin,usr/sbin}
cp -r _install/* rootfs/

# Create minimal init
cat <<EOF > rootfs/etc/inittab
::sysinit:/etc/init.d/rcS
::askfirst:-/bin/sh
::ctrlaltdel:/bin/umount -a -r
EOF

mkdir -p rootfs/etc/init.d
cat <<EOF > rootfs/etc/init.d/rcS
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
echo "Minimal Linux Booted in QEMU."
EOF
chmod +x rootfs/etc/init.d/rcS

# Package RootFS
cd rootfs
find . | cpio -H newc -o | gzip > ../rootfs.cpio.gz
cd ..
```

### Step 5: Run QEMU

```bash
qemu-system-arm \
  -M versatilepb \
  -m 128M \
  -kernel zImage \
  -initrd rootfs.cpio.gz \
  -append "console=ttyAMA0" \
  -nographic
```

---

## Phase 2: Build for Raspberry Pi 3

### Step 1: Download Official Raspberry Pi Kernel

- Download `kernel7.img` from the Raspberry Pi firmware repository.
    
- Download the matching Device Tree Blob (DTB) `bcm2710-rpi-3-b.dtb`.
    

### Step 2: Cross-compile BusyBox for ARMv7

```bash
make clean
make defconfig
make menuconfig
```

In `menuconfig`:

- Set target architecture to `ARM Little Endian`
    
- Compiler Prefix: `arm-none-eabi-`
    
- Enable static binary build
    

Build:

```bash
make -j$(sysctl -n hw.ncpu) ARCH=arm CROSS_COMPILE=arm-none-eabi-
make install
```

### Step 3: Build Raspberry Pi Root Filesystem

```bash
mkdir -p rootfs/{dev,proc,sys,etc,home,tmp,bin,sbin,usr/bin,usr/sbin}
cp -r _install/* rootfs/

mkdir -p rootfs/etc/init.d
cat <<EOF > rootfs/etc/init.d/rcS
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
echo "Minimal Linux Booted on Pi."
EOF
chmod +x rootfs/etc/init.d/rcS

cd rootfs
find . | cpio -H newc -o | gzip > ../rootfs.cpio.gz
cd ..
```

### Step 4: Prepare SD Card

- Flash a minimal Raspbian Lite image or clean SD card partitioning.
    
- Replace `/boot/kernel7.img` with downloaded or built kernel.
    
- Place `rootfs.cpio.gz` in `/boot/`.
    

Edit `/boot/config.txt`:

```
initramfs rootfs.cpio.gz followkernel
```

Edit `/boot/cmdline.txt`:

```
console=serial0,115200 console=tty1 root=/dev/ram0 rw init=/bin/sh
```

### Step 5: Boot Raspberry Pi 3

- Insert SD card.
    
- Connect serial console or monitor + keyboard.
    
- Power on.
    

---

## Deliverable Milestones

-  Boot BusyBox in QEMU
    
-  Boot BusyBox on Pi 3
    
-  Build service scripts (e.g., GPIO toggles)
    
-  Connect UART between Pi 3 and RP2040 for communication
    
-  Add basic networking (e.g., minimal SSH server)
    

---

## Notes

- Always build BusyBox statically to avoid dependency on glibc or musl.
    
- Minimal init systems keep boot time low and allow manual control.
    
- QEMU-first approach validates rootfs and boot process before hardware deployment.
    
- Serial console setup is critical for debugging.
    

---

## Next Steps

- Add simple network service (UDP or TCP heartbeat).
    
- Cross-compile additional small utilities for Pi 3.
    
- Test GPIO control and simple peripheral drivers.
    
- Set up OTA foundation for future updates.
    
- Evaluate move to custom kernel builds if additional features required.
    

---