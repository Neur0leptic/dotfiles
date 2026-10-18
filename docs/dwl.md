# DWL

The package manager (Portage on Gentoo, makepkg on Arch) builds DWL from upstream DWL,
the desktop patch in `dot_config/dwl/patches/` and your `config.h`.

## Settings

`~/.local/src/dwl/config.h` (Super+C opens it) has every DWL setting: shortcuts,
window rules, colors, displays, keyboard, mouse and renderer. After editing it, run:

```sh
update_dwl.sh               # rebuild DWL; the running session ends, log in again
update_dwl.sh --no-restart  # rebuild DWL; the session runs on until you log out
```

- Keep the two marked sections, `machine settings` and `output rules`, with their
  markers: they hold this computer's own settings, which the sync keeps for this
  machine only. Without the markers the sync stops.
- A display rule names the connector, such as `eDP-1`, and the monitor's EDID
  fingerprint, so it applies only to that monitor.
- `DWL_RENDERER` selects the renderer: `"vulkan"`, `"gles2"`, or `""` to let wlroots
  choose.
- If DWL does not start, switch to another console with Ctrl+Alt+F2, log in and run
  `start-dwl --safe`. It starts DWL with the GLES2 renderer and without wide color, so
  you can fix `config.h`.

Where DWL was built into `~/.local` instead of by the package manager, `update_dwl.sh`
rebuilds it there.

## Updating DWL itself

The upstream DWL commit is pinned in three places: the Gentoo ebuild (`gui-wm/dwl` in
neurogentoo, with its Manifest), the Arch recipe (`pkgbuilds/dwl-neuroleptic` in
neuroarch, with its checksum) and the `~/.local` build in
`dot_local/bin/executable_update_dwl.sh`. To move to a newer commit, check that the
patch applies to it (`git apply --check`), update all three, publish them and rebuild
DWL on each machine. `update_dwl.sh` alone never switches to a new upstream commit.
