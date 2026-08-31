# Optional dwl Session Plan

## Safety boundary

- Hyprland remains installed, configured, and the default tty1 session.
- The live Hyprland Lua configuration and `start-hyprland` path are not replaced.
- The chezmoi desktop selection remains `hyprland`.
- `xdg-desktop-portal-hyprland` and the Hyprland session files remain installed.
- dwl is an optional session and refuses to start while Hyprland is running.

## Source and build

- Upstream: `https://codeberg.org/dwl/dwl.git`
- Branch: `wlroots-next`
- Pinned base: `d41ecb745cc94fbb48e93af01f5fd5d0b2488945`
- wlroots ABI: `wlroots-0.20`
- User install prefix on Arch: `${HOME}/.local`
- XWayland is disabled in the dwl build. The system XWayland package is not removed.
- The reproducible local patch is stored under `~/.config/dwl/patches/`.

`update_dwl.sh` remains one cross-distribution script:

- On Arch or Arch-derived systems, it uses the pinned source plus the managed
  patch, builds the optional Arch dwl, and installs it under `~/.local`.
- On non-Arch systems, it keeps the existing Gentoo build path and aggressive
  Clang/LTO flags.
- A successful update never reboots the machine. If dwl is active, it ends the
  dwl session with SIGTERM so the next session loads the new binary.

## Deliberate patch set

The maintained integrated patch contains only the required parts of:

- color_manager
- dwl IPC v2 for Waybar
- customfloat
- numlock-capslock
- unclutter
- movestack
- the minimal PID/geometry portion of spawninfo

It also contains small local implementations for:

- ten global tags
- tags 1-5 assigned to HDMI-A-1 and tags 6-10 assigned to eDP-1
- temporary tag fallback when an assigned output is missing
- deterministic client rehoming when that output returns
- single-tag-only view semantics for keyboard and IPC requests
- smart zero borders for fullscreen and single tiled clients
- Super+wheel tag traversal
- global keyboard layout notification without per-client layout state
- tested 10-bit output-state fallback
- focus-existing-LibreWolf support for wopen

The following are intentionally excluded to keep code and runtime state small:

- scratchpad patches and scratchpad binds
- sticky
- swapandfocusdir
- cfact
- pertag
- vanity gaps
- monitorconfig
- gesture support
- XWayland

## Runtime configuration

- Native master-stack layout
- No gaps
- Two-pixel borders
- Focus color `#99d8fe`
- Inactive border and root background `#000000`
- No wallpaper, blur, shadow, transparency, animation, or rounded corners
- Keyboard layouts `us,de,tr` with `grp:alt_shift_toggle`
- Repeat rate 105 and delay 180 ms
- Num Lock enabled
- Sloppy focus
- Cursor hidden after three seconds

Outputs when both are connected:

- HDMI-A-1: 3840x2160 at 60 Hz, scale 2, logical position 0,0
- eDP-1: 1920x1080 at 144.028 Hz, scale 1.5, logical position 1920,0

If an output disappears, its tags and clients remain accessible on the other
output. When it returns, its tagged clients are moved back to their canonical
output.

## Color modes

`start-dwl` starts the selected experimental wide-color path:

- Vulkan renderer
- `/dev/dri/renderD128`
- HDMI attempts XBGR2101010, then XRGB2101010
- BT.2020 primaries with an SDR transfer function, matching the active
  Hyprland `wide` preset rather than enabling PQ HDR
- failed output-state tests fall back to XRGB8888

`start-dwl --safe` uses GLES2 and 8-bit sRGB.

## Session model

- tty1 keeps the existing automatic Hyprland login behavior.
- After logging out of Hyprland, dwl is started from tty2 with `start-dwl`.
- `start-dwl --safe` is the recovery command.
- Super+Backspace exits only the current dwl session.
- dwl and Hyprland are not run concurrently because they share the user bus,
  portal environment, and compositor-aware helper scripts.

## Desktop integration

- Waybar remains on-demand through Super+B.
- Hyprland keeps the current Waybar configuration.
- dwl uses a separate config and stylesheet, but imports the exact existing
  palette and only adds dwl selector mappings.
- The first dwl bar shows tags 1-10 on each connected output so all tags remain
  visible and clickable during single-output fallback.
- dwl uses a separate swayidle configuration with wlopm for DPMS.
- xdg-desktop-portal-wlr is selected only in the dwl environment; the Hyprland
  portal remains selected in Hyprland.
- Shared helpers detect the active compositor from session environment, never
  merely from the presence of `hyprctl`.

## Verification order

1. Build and static validation.
2. Nested Wayland/GLES2 launch without the normal autostart stack.
3. Real tty safe-mode test.
4. Input, tags, hotplug, rules, Waybar, lock, DPMS, screenshot, recording, and
   portal tests.
5. Vulkan and 10-bit test with explicit effective-format logging.
6. Exit dwl, return to tty1, and verify `hyprctl configerrors` plus the existing
   Hyprland helpers.
