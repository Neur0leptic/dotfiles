URL="ENTER YOUR URL"

cd "/usr/src/linux"
rm -fv ".config"
make mrproper
export LLVM="1" LLVM_IAS="1" CFLAGS="-O3 -march=native -pipe" KCFLAGS="-O3 -march=native -pipe"
curl -L "${URL}" -o ".config"
make -j4 -l5
KERNEL_PATH="/boot/EFI/BOOT/BOOTX64.EFI"
NEW_KERNEL="/usr/src/linux/arch/x86/boot/bzImage"
cp -fv "${NEW_KERNEL}" "${KERNEL_PATH}"

ls -la "/boot/EFI/BOOT"
du -h "/boot/EFI/BOOT"
ls -la "/boot/EFI/BOOT/BOOTX64.EFI"
cd "/boot/EFI/BOOT"
ls -la
