# Themes and browsers

Chezmoi manages the current application settings, the Neurowave GTK/Kvantum
assets and the portable LibreWolf CSS files. Browser profiles, cookies, login
data and history are not part of this repository.

## LibreWolf and Helium

LibreWolf's personal UI preferences use its native `librewolf.overrides.cfg`.
The source directory's `private_` attribute keeps `~/.librewolf` at mode 0700;
it does not encrypt the public override file or include runtime profiles.
The installer attaches the active profile's CSS files to the managed files in
`~/.config/librewolf/chrome/`. Edit those files when changing the CSS theme;
the profile links do not require a second copy or a fixed profile name.

The LibreWolf theme uses Neurowave's black canvas, dark surfaces, purple menu
selection, blue primary actions and cyan focus indicators. Native design tokens
keep disabled controls and security warnings distinct. Content styling is limited
to internal `about:` pages; website styles are not overridden.

Native text-selection colors also live in `librewolf.overrides.cfg`: a blue
selection background, black selected text and a pale-blue inactive selection.
These cover native controls such as the address field where userChrome selection
rules can be ignored during painting. They are loaded on browser startup.

The existing `setup_librewolf.sh` is unchanged. The installer calls it as the
target user and reports success or failure. It is not a Chezmoi hook and does
not run during routine synchronization.

Helium uses the system GTK theme. `helium-browser-theme.json` contains only
the portable appearance selection. The installer initializes those fields;
the live browser's `Preferences` file is not managed by Chezmoi. An open Helium
instance is not closed automatically to update its profile.

### Extensions

`~/.config/browser-extensions.json` is the portable extension selection. The
installer's `browser-extensions` stage prepares native system policies, without
starting browsers or copying profile data. Routine synchronization only updates
the manifest; it does not deploy system policies or install extensions.

LibreWolf installs uBlock Origin, Vimium, I still don't care about cookies,
Dark Background and Light Text, and Bypass Paywalls Clean. AMO download URLs
follow the latest compatible release. Bypass Paywalls Clean's initial download
comes from its upstream update manifest; subsequent updates use the extension's
own update mechanism. No local Downloads path or manually maintained version is
required.

Helium installs Vimium and I still don't care about cookies. Its native Web Store
update URL is deliberately a placeholder that Helium maps to its own extension
proxy. Do not replace it with a direct Google download URL. Downloads wait for
Helium's normal services consent and enabled extension proxy; those preferences
are not forced by the installer.

The policies use `normal_installed`, so extensions are installed automatically
on online startup but users can disable them. They are system-wide: LibreWolf
uses `/etc/librewolf/policies/policies.json`; Helium's Linux build uses the shared
`/etc/chromium/policies/managed/` namespace. Any other Chromium build sharing
that namespace sees the same extension policy. Existing conflicting fields stop
setup instead of being overwritten. LibreWolf's packaged policies and unrelated
system policies are preserved. Existing extension settings are not exported or
reset. To redeploy after editing the manifest, resume at `browser-extensions`
(or `full-browser-extensions` in the full sequence).

## Neurowave editor

`~/.config/neurowave/` contains the existing generator, palette and application
templates. This is an optional theme-editing tool, not an automatic apply hook.
It generates full configuration files for its supported applications, not only
colors. Review its templates before intentionally rebuilding configurations.
LibreWolf output goes to the portable CSS files, independently of profile names;
the profile links load those files after browser setup.

The existing sync workflow tracks the resulting managed files normally; it
does not rerun the generator. GTK applications following the system theme and
Qt applications using Kvantum can inherit Neurowave. Applications with their
own theme format need a corresponding native theme file or generator template.
Only add stable theme/settings inputs, not an application's runtime profile.
