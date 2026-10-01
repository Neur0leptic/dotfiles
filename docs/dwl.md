# DWL

## Source

- Upstream: `https://codeberg.org/dwl/dwl.git`
- Pinned commit: `d41ecb745cc94fbb48e93af01f5fd5d0b2488945`
- wlroots ABI: `wlroots-0.20`
- Patch: `~/.config/dwl/patches/0001-neuroleptic.patch`

## Commands

- `update_dwl.sh`: rebuilds package-owned DWL through Portage/makepkg when the
  synchronized patch/protocol changed; standalone installations retain their
  user-local build path. A successful rebuild exits a running DWL session.
- `start-dwl`: uses the renderer and per-output preferences in `machineSettings`.
  Portable defaults let wlroots choose the renderer. Older Intel presets use GLES2;
  Vulkan and wide color are explicit preferences.
- `start-dwl --safe`: starts dwl with the GLES2 renderer and sRGB mode.

## Packaged builds

The Gentoo live ebuild and Arch VCS PKGBUILD use the same ABI-compatible upstream
commit and follow public dotfiles `main` for
`dot_config/dwl/patches/0001-neuroleptic.patch` and
`dot_config/dwl/protocols/dwl-ipc-unstable-v2.xml`. The patch includes `config.def.h`:
keybindings and shared compositor behavior are compiled into the package.
Git inputs are declared through `git-r3` and makepkg VCS sources; the immutable
upstream archive retains its checksum. Both inputs come from one dotfiles checkout
per build, and the installed package records them for comparison.
No manually maintained dotfiles commit/checksum is required.
The installer links `~/.local/bin/dwl` to the packaged `/usr/bin/dwl`.

Chezmoi separately supplies `start-dwl`, `dwl-autostart` and
`~/.config/dwl/outputs.json`. Editing runtime preferences does not rebuild DWL.
Use the existing `sync_chezmoi.sh` to synchronize/publish dotfiles. Then run
`update_dwl.sh` if the compiled patch/protocol changed. It resolves the synchronized
commit automatically, does not publish anything, and skips unchanged build inputs.
Normal package rebuilds follow `main`; installer resume accepts newer synchronized
dotfiles without demanding the original installation's commit.

## Selecting a newer upstream DWL revision

`update_dwl.sh` updates the canonical patch/protocol, not the selected Codeberg
revision. Moving to a new upstream release is a deliberate package-recipe update:

1. Select the release/tag or commit. Check the canonical patch with
   `git apply --check` in a separate checkout of that revision. If necessary,
   adapt the canonical patch/protocol and review the required wlroots ABI.
2. Update `DWL_COMMIT`, `SOURCE_SHA256` and `Manifest` in neurogentoo's
   `gui-wm/dwl/`; update `_dwl`, the archive checksum, package release/version and
   wlroots dependency in the installer's
   `packaging/arch/pkgbuilds/dwl-neuroleptic/PKGBUILD`. Both recipes must select
   the same upstream revision. Keep the standalone Arch `ref` in the Chezmoi
   `dot_local/bin/executable_update_dwl.sh` aligned as well.
3. Publish any dotfiles changes with the existing `sync_chezmoi.sh` workflow,
   then publish the neurogentoo and installer recipe changes.
4. On Gentoo, sync neurogentoo and explicitly rebuild `gui-wm/dwl-9999`. On Arch,
   build/install the updated PKGBUILD with makepkg. An already installed Arch
   package contains its previous recipe; syncing dotfiles does not replace it.

For a recipe-only upstream change, do not rely on `update_dwl.sh`: unchanged
patch/protocol inputs intentionally skip its rebuild. Upstream archive checksums
change only when selecting a different upstream archive, not on routine dotfiles
updates. Patch applicability alone does not prove compilation or runtime compatibility.

## Machine preferences

`machineSettings` is a JSON string in Chezmoi data. The installer collects it on
both distributions; it also accepts a JSON file through `--display-config`.
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

The launcher exports `DWL_TAG_OUTPUT_1` through `DWL_TAG_OUTPUT_10`,
`DWL_WIDE_OUTPUTS`, XKB defaults and optional mouse/render-device settings from
the approved data. The compiled patch has no fixed HDMI/eDP routing. Restart the
session after changing tag routing or renderer settings; `dwl-outputs` reapplies
resolution, scale and placement. `start-dwl --safe` forces GLES2/sRGB.

## Standalone builds

`update_dwl.sh` remains available for standalone user-local installations:

- Arch: builds the pinned commit with the managed patch and installs it under
  `~/.local`.
- Gentoo: builds the existing `~/.local/src/dwl` tree with the Clang/ThinLTO
  `no_polly` profile and installs it under `~/.local`.
