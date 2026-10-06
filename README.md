# Dotfiles

Personal Linux configuration managed with [chezmoi](https://www.chezmoi.io/).

- Hyprland with an optional DWL session
- NVIDIA, Intel X220, and modern AMD/Intel profiles
- Feature-based configuration

## Setup

```sh
chezmoi init https://github.com/Neur0leptic/dotfiles.git
chezmoi diff
chezmoi apply
```

Review changes before applying. Do not bulk-add `$HOME` or `~/.config`.

## Daily changes

Edit the managed files in your home directory, then run `sync_chezmoi.sh`.
It captures local edits, commits, pulls/rebases, applies the merged files and
pushes private then public sources. Non-overlapping edits to the literal parts
of templates are merged automatically without replacing machine-specific
expressions. Genuine overlaps or ambiguous generated-field changes preserve
both versions and stop before publication. Routine sync does not run setup
scripts, external downloads or the Neurowave generator.

See [DWL notes](docs/dwl.md).
See [themes and browser configuration](docs/themes.md) for Neurowave and browser scope.
