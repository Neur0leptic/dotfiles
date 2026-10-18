# Themes and browsers

## Theme

The desktop uses the Neurowave colors. GTK applications follow the GTK theme, Qt
applications use Kvantum, and the other applications have their own theme files in
`~/.config/`.

`~/.config/neurowave/` holds an optional generator that rebuilds those files from one
palette. It writes complete configuration files, so review its templates before you
run it. The sync never runs it.

## Browsers

- LibreWolf: the CSS theme is in `~/.config/librewolf/chrome/` and the preferences in
  `~/.librewolf/librewolf.overrides.cfg`. Extensions: uBlock Origin, Vimium, I still
  don't care about cookies, Dark Background and Light Text, and Bypass Paywalls Clean.
- Helium follows the GTK theme. Extensions: Vimium and I still don't care about
  cookies; Helium downloads them once its services consent and extension proxy are on.

`~/.config/browser-extensions.json` lists the extensions. The installer turns the list
into system policies, so each browser installs them on its next start with internet
access; you can still turn them off. After changing the list, run the installer's
extension stage again as root: `install-system continue --step browser-extensions`
(`full-browser-extensions` in the full tier).

Browser profiles, cookies, logins and history are not part of the dotfiles.
