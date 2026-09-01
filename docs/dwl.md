# DWL

## Source

- Upstream: `https://codeberg.org/dwl/dwl.git`
- Pinned commit: `d41ecb745cc94fbb48e93af01f5fd5d0b2488945`
- wlroots ABI: `wlroots-0.20`
- Patch: `~/.config/dwl/patches/0001-neuroleptic.patch`

## Commands

- `update_dwl.sh`: builds and installs dwl.
- `start-dwl`: starts dwl with the Vulkan renderer and wide color mode.
- `start-dwl --safe`: starts dwl with the GLES2 renderer and sRGB mode.

## Builds

- Arch: builds the pinned commit with the managed patch and installs it under
  `~/.local`.
- Gentoo: builds the existing `~/.local/src/dwl` tree with the Clang/ThinLTO
  `no_polly` profile and installs it under `~/.local`.
