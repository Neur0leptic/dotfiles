# Dotfiles

The author's Linux configuration, managed with [chezmoi](https://www.chezmoi.io/): a
Wayland desktop with Hyprland or DWL, plus Waybar, foot, Zsh, Neovim, LibreWolf and
other applications.

## Installation

The [installer](https://github.com/Neur0leptic/install-system) sets them up together
with the packages they need. To apply them on an existing system:

```sh
chezmoi init https://github.com/Neur0leptic/dotfiles.git
chezmoi diff
chezmoi apply
```

`chezmoi init` asks a few questions, such as the desktop. Read `chezmoi diff` first:
`chezmoi apply` replaces the files it manages.

## Usage

Log in on the first console; Hyprland or DWL starts automatically.

Edit the files in your home directory, then run `sync_chezmoi.sh`. It saves the edits
in `~/.local/share/chezmoi`, merges them with what your other machines pushed, updates
this machine and pushes the result. Pushing needs write access to this repository, so
keep your own changes in your own fork.

## Settings

- Hyprland: `~/.config/hypr/`; Super+C opens one of its files. `machine.lua` has this
  computer's displays, keyboard and mouse, and `binds.lua` the shortcuts.
- DWL: `~/.local/src/dwl/config.h`, opened by Super+C, has every DWL setting,
  including the displays, keyboard, mouse and renderer. See [DWL](docs/dwl.md).
- Zsh and environment: `~/.config/zsh/` and `~/.config/shell/`.
- Themes and browsers: see [themes and browsers](docs/themes.md).
