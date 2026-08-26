# Dotfiles

Chezmoi source for the Linux machines. Hyprland is managed; the DWL source
tree and its unfinished configuration will be added later.

GPU behavior is selected independently during `chezmoi init`:

- `nvidia`: proprietary NVIDIA, NVDEC and Vulkan
- `intel-x220`: ThinkPad X220 Intel HD Graphics 3000, i965 VA-API and OpenGL
- `modern-amd-intel`: modern AMD or Intel, automatic VA-API driver and Vulkan

The GPU profile does not select the operating system or compositor.

## Safety

- The repository uses an explicit allowlist. Never run `chezmoi add ~/.config`.
- Stable secrets are GPG-encrypted in a separate private chezmoi source.
- Browser profiles, messaging databases, cookies and runtime state are excluded.
- This repository contains no `.chezmoiremove` file and no cleanup script.
- Files marked for manual deletion are never removed by `chezmoi apply`.

## Bootstrap

```sh
chezmoi init <repository-url>
chezmoi diff
chezmoi apply
```

Clone the private repository to
`~/.local/share/chezmoi-private`, then apply it with a separate state file:

```sh
private_source="${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi-private"
private_state="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi-private.boltdb"

chezmoi -S "$private_source" --persistent-state "$private_state" diff
chezmoi -S "$private_source" --persistent-state "$private_state" apply
```

Both sources use the same chezmoi config and GPG recipient. The GPG private key
must be restored from an independent secure backup before the private overlay
can be applied.

`docs/private-source-allowlist.txt` mirrors the private repository's encrypted
source allowlist so public sync validation remains fail-closed without access
to private contents.

The portable-font bootstrap requires `bsdtar`, `curl`, the fontconfig command
line tools, and standard POSIX utilities. Its fontconfig intentionally scans
the verified portable tree plus the standard system font roots. Candy Icons is
installed automatically from a checksum-verified, commit-pinned archive.

## External projects

Neurowave, Roflix, YourPipe, the KeePass frontend, the WireGuard manager and
the research helpers still need repository URLs before they can be added to
`.chezmoiexternal.toml`. Their current source trees are intentionally not
duplicated here.

The detailed migration manifest is stored locally at `~/vimwiki/Repo.md`.
