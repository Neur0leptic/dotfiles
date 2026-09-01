# Dotfiles

Personal Linux configuration managed with [chezmoi](https://www.chezmoi.io/).

- Hyprland with an optional DWL session
- NVIDIA, Intel X220, and modern AMD/Intel profiles
- Feature-based configuration
- Secrets stored in a separate GPG-encrypted repository

## Setup

```sh
chezmoi init https://github.com/Neur0leptic/dotfiles.git
chezmoi diff
chezmoi apply
```

Review changes before applying. Do not bulk-add `$HOME` or `~/.config`.

See [DWL notes](docs/dwl.md).
