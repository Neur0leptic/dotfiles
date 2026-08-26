#!/bin/bash

LINUX_DIR="/usr/src/linux"
NEW_KERNEL="${LINUX_DIR}/arch/x86/boot/bzImage"
KERNEL_PATH="/boot/EFI/BOOT/BOOTX64.EFI"
PARTITION_BOOT="$(lsblk -nlo NAME,RM,PARTTYPE |
        sed -n '/0\s*c12a7328-f81f-11d2-ba4b-00a0c93ec93b/ {s|^[^ ]*|/dev/&|; s| .*||p; q}')"

export LLVM="1" LLVM_IAS="1" CFLAGS="-O3 -march=native -pipe"

make -C "${LINUX_DIR}" -j"$(nproc)" -l"$(($(nproc) + 1))"

make -C "${LINUX_DIR}" modules_install

mount "${PARTITION_BOOT}" "/boot"
cp -f "${NEW_KERNEL}" "${KERNEL_PATH}"
