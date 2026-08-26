#!/bin/sh

cd "$HOME/.local/src/dwl"
CC=clang CFLAGS="-fno-pic -fno-pie -Ofast -flto=full -pipe -march=native -mtune=native -fomit-frame-pointer -funroll-loops" LDFLAGS="-fuse-ld=lld -rtlib=compiler-rt -unwindlib=libunwind -Wl,-O3 -Wl,--as-needed -Wl,--gc-sections -Wl,--icf=all" make

doas make install

if command -v openrc-shutdown > /dev/null 2>&1; then
        doas openrc-shutdown -r now
else
        sudo systemctl reboot
fi
