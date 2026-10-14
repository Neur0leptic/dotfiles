# DWL

## Source

- Upstream: `https://codeberg.org/dwl/dwl.git`
- Pinned commit: `d41ecb745cc94fbb48e93af01f5fd5d0b2488945`
- wlroots ABI: `wlroots-0.20`
- Patch: `~/.config/dwl/patches/0001-neuroleptic.patch`

## Commands

- Edit `~/.local/src/dwl/config.h` (also opened by Super+C), then run
  `update_dwl.sh`. Local header edits need no prior dotfile publication. This file
  contains keybindings, floating rules, outputs/scales/tag routing, keyboard/pointer
  preferences and renderer/cursor settings.
- `update_dwl.sh`: rebuilds package-owned DWL through Portage/makepkg when the user
  header or feature patch/protocol changed. A successful rebuild exits a running
  DWL session; `--no-restart` keeps it running until the next login.
- `start-dwl`: starts the compiled settings without another output/keyboard
  configuration overriding them. Portable defaults let wlroots choose the renderer.
- `start-dwl --safe`: starts dwl with the GLES2 renderer and sRGB mode.

## Packaged builds

The Gentoo live ebuild and Arch VCS PKGBUILD use the same ABI-compatible upstream
commit and follow public dotfiles `main` for
`dot_config/dwl/patches/0001-neuroleptic.patch` and
`dot_config/dwl/protocols/dwl-ipc-unstable-v2.xml`. The patch changes compositor
features, not personal settings. Shared settings and portable machine defaults are in
`dot_config/dwl/config.def.h`. The installer seeds the user's `config.h` from this
machine's saved sections when it has any, otherwise from those defaults and the
approved answers. It only creates a missing header; later runs preserve that file.
Git inputs are declared through `git-r3` and makepkg VCS sources; the immutable
upstream archive retains its checksum. Both inputs come from one dotfiles checkout
per build, and the installed package records them for comparison.
No manually maintained dotfiles commit/checksum is required.
The installer links `~/.local/bin/dwl` to the packaged `/usr/bin/dwl`.

Chezmoi manages `config.h`, `start-dwl` and `dwl-autostart`, not the upstream source
tree or build artifacts. The header has two marked sections: `machine settings`
(renderer, render device, mouse, keyboard layout and options) and `output rules`
(displays). Normal `sync_chezmoi.sh` keeps everything else in `config.def.h`, shared
by all machines, and the two sections in `dwl-machines/<profile>.h` for this machine
only; Chezmoi joins them again. Shared edits therefore reach every machine, while each
keeps its own displays and input devices. Keep both sections and their markers; the
sync stops without changing anything when they are missing. The profile is the
hardware's vendor and model, such as `lenovo-thinkpad-x220`, or `dwlConfigProfile` in
the data of Chezmoi's config when set. A machine without saved sections starts from
its own answers, never another machine's. Overlapping edits stop without overwriting
either version; non-overlapping edits merge. When a sync changes the header, it asks
for `update_dwl.sh`. Installer apply leaves the header alone, so continue never
overwrites edits.

Gentoo's updater hands that same active header to native savedconfig with backups and
conflict checks; Arch's makepkg build consumes a frozen copy of the same header.
Replaced savedconfigs are kept under `/var/lib/install-system/dwl-backups`, with
their original paths in the adjacent `.path` files. Its prepared/pending headers
are recovery receipts, not additional editable settings. Finish an interrupted
handoff with the same header before preparing a different one.
Use the existing `sync_chezmoi.sh` to synchronize/publish dotfiles, including header
edits, whenever desired; publication is not a prerequisite for a local rebuild. Run
`update_dwl.sh` if the compiled patch/protocol changed. It resolves the synchronized
commit automatically, does not publish anything, and skips unchanged build inputs.
Feature updates still follow published `main`; header-only edits do not need a
feature update. Package/input checks compare the actual built header as well.

## Selecting a newer upstream DWL revision

`update_dwl.sh` updates the canonical patch/protocol, not the selected Codeberg
revision. Moving to a new upstream release is a deliberate package-recipe update:

1. Select the release/tag or commit. Check the canonical patch with
   `git apply --check` in a separate checkout of that revision. If necessary,
   adapt the canonical patch/protocol and review the required wlroots ABI.
2. Update `DWL_COMMIT` and the archive `Manifest` in neurogentoo's
   `gui-wm/dwl/`; update `_dwl`, the archive checksum, package release/version and
   wlroots dependency in
   `neuroarch/pkgbuilds/dwl-neuroleptic/PKGBUILD`. Both recipes must select
   the same upstream revision. Keep the standalone Arch `ref` in the Chezmoi
   `dot_local/bin/executable_update_dwl.sh` aligned as well.
3. Publish any dotfiles changes with the existing `sync_chezmoi.sh` workflow,
   then publish the neurogentoo and neuroarch recipe changes.
4. On Gentoo, sync neurogentoo and explicitly rebuild `gui-wm/dwl-9999`. On Arch,
   build/install the updated PKGBUILD with makepkg. An already installed Arch
   package contains its previous recipe; syncing dotfiles does not replace it.

For a recipe-only upstream change, do not rely on `update_dwl.sh`: unchanged
patch/protocol inputs intentionally skip its rebuild. Upstream archive checksums
change only when selecting a different upstream archive, not on routine dotfiles
updates. Patch applicability alone does not prove compilation or runtime compatibility.

## Machine preferences

`machineSettings` holds the installer answers used to seed `config.h` once on
both distributions; the installer also accepts a JSON file through `--display-config`.
After installation, edit the native header, not the old answer record or the saved
sections in `dwl-machines/`. Normal sync records those edits.
For example:

```json
{
  "schema": 1,
  "renderer": "auto",
  "vaapi": "auto",
  "keyboardLayout": "us,de,tr",
  "outputs": [
    {"name": "DP-1", "mode": "2560x1440@144", "scale": 1.25,
     "position": "0,0", "tags": [1,2,3,4,5], "color": "srgb"}
  ]
}
```

An empty `outputs` list leaves output selection to the compositor. Optional
fields include `renderDevice` (a DRM render node), `keyboardOptions`, `mouse`
(lowercase, spaces replaced by hyphens), `sensitivity`, `backlight` and
`wireguardProfile` (an already provisioned private profile, never inferred).
The same output, workspace and input answers feed Hyprland.

The installer offers known presets by DMI model and records monitor EDID hashes.
At session start/output application, a mismatched monitor is skipped even if its
connector name is unchanged. Unconfigured outputs retain compositor defaults.

Native monitor rules include the EDID identity guard, tag mask, mode, scale,
position and optional wide color. Keyboard and renderer preferences are also in
the header. Rebuild and restart after edits. `start-dwl --safe` forces GLES2/sRGB.
The legacy `dwl-outputs` helper remains available but is not run at session start.

## Standalone builds

`update_dwl.sh` remains available for standalone user-local installations:

- Arch: builds the pinned commit with the managed patch and installs it under
  `~/.local`.
- Gentoo: builds the existing `~/.local/src/dwl` tree with the Clang/ThinLTO
  `no_polly` profile and installs it under `~/.local`.
