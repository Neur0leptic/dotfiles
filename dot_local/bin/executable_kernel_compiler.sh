#!/bin/bash
# Builds /usr/src/linux with LLVM and installs it as the EFI stub kernel. Run it as root
# (doas kernel_compiler.sh); the previous kernel is kept next to it as BOOTX64.EFI.prev.
set -eu

LINUX_DIR="/usr/src/linux"
NEW_KERNEL="${LINUX_DIR}/arch/x86/boot/bzImage"
KERNEL_PATH="/boot/EFI/BOOT/BOOTX64.EFI"
PARTITION_BOOT="$(lsblk -nlo NAME,RM,PARTTYPE |
        sed -n '/0\s*c12a7328-f81f-11d2-ba4b-00a0c93ec93b/ {s|^[^ ]*|/dev/&|; s| .*||p; q}')"

# doas resets PATH, and clang lives under /usr/lib/llvm/<version>/bin.
. /etc/profile.env
export LLVM="1" LLVM_IAS="1"

make -C "${LINUX_DIR}" -j"$(nproc)" -l"$(($(nproc) + 1))"

if grep -q '^CONFIG_MODULES=y' "${LINUX_DIR}/.config"; then
        make -C "${LINUX_DIR}" modules_install
fi

mountpoint -q /boot || mount "${PARTITION_BOOT}" "/boot"
[ ! -f "${KERNEL_PATH}" ] || cp -f "${KERNEL_PATH}" "${KERNEL_PATH}.prev"
cp -f "${NEW_KERNEL}" "${KERNEL_PATH}"
