-- Fullscreen workspaces (no gaps, no border, no rounding for tiled windows)
hl.window_rule({ match = { float = false, workspace = "f[1]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]" }, rounding = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, rounding = 0 })

-- Fullscreen class
hl.window_rule({ match = { class = "^(fullscreen)$" }, fullscreen = true })

-- Sizes come from the key bindings; max_size only shrinks windows that do not fit the screen.
local fit_screen = { "monitor_w*0.9", "monitor_h*0.9" }
-- The note pad keeps its tall 65x45 shape (about 0.69 wide per unit of height) when shrunk.
local fit_pad = { "monitor_h*0.62", "monitor_h*0.9" }

-- Floating windows
hl.window_rule({ match = { class = "^(floating)$" }, float = true })
hl.window_rule({ match = { class = "^(floating)$" }, max_size = fit_screen })
hl.window_rule({ match = { class = "^(floating)$" }, center = true })

-- Vim wiki
hl.window_rule({ match = { class = "^(vim-wiki-float)$" }, float = true })
hl.window_rule({ match = { class = "^(vim-wiki-float)$" }, max_size = fit_pad })
hl.window_rule({ match = { class = "^(vim-wiki-float)$" }, center = true })

-- Opencode
hl.window_rule({ match = { class = "^(opencode-float)$" }, float = true })
hl.window_rule({ match = { class = "^(opencode-float)$" }, max_size = fit_screen })
hl.window_rule({ match = { class = "^(opencode-float)$" }, center = true })

-- Torrent
hl.window_rule({ match = { class = "^(torrent-float)$" }, float = true })
hl.window_rule({ match = { class = "^(torrent-float)$" }, size = "1000 600" })
hl.window_rule({ match = { class = "^(torrent-float)$" }, center = true })

-- Translator
hl.window_rule({ match = { class = "^(translator)$" }, float = true })
hl.window_rule({ match = { class = "^(translator)$" }, max_size = fit_screen })
hl.window_rule({ match = { class = "^(translator)$" }, center = true })

-- Clipse
hl.window_rule({ match = { class = "clipse" }, float = true })
hl.window_rule({ match = { class = "clipse" }, max_size = fit_screen })
hl.window_rule({ match = { class = "clipse" }, center = true })

-- Anki
hl.window_rule({ match = { class = "anki" }, float = true })
hl.window_rule({ match = { class = "anki" }, size = "700 600" })
hl.window_rule({ match = { class = "anki" }, center = true })

-- LocalSend
hl.window_rule({ match = { class = "localsend" }, float = true })
hl.window_rule({ match = { class = "localsend" }, size = "400 700" })
hl.window_rule({ match = { class = "localsend" }, center = true })

-- YouTube info
hl.window_rule({ match = { class = "^(youtube-info)$" }, float = true })
hl.window_rule({ match = { class = "^(youtube-info)$" }, size = "900 900" })
hl.window_rule({ match = { class = "^(youtube-info)$" }, center = true })

-- Roflix info terminals (the dotted ID is required by GTK applications)
hl.window_rule({ match = { class = "^(roflix-info|org\\.roflix\\.Info)$" }, float = true })
hl.window_rule({ match = { class = "^(roflix-info|org\\.roflix\\.Info)$" }, size = "1000 850" })
hl.window_rule({ match = { class = "^(roflix-info|org\\.roflix\\.Info)$" }, center = true })

-- Audio Player (YourPipe)
hl.window_rule({ match = { class = "^(audio-player)$" }, float = true })
hl.window_rule({ match = { class = "^(audio-player)$" }, size = "800 500" })
hl.window_rule({ match = { class = "^(audio-player)$" }, center = true })

-- KeePassXC (kprofi)
hl.window_rule({ match = { class = "^(kprofi)$" }, float = true })
hl.window_rule({ match = { class = "^(kprofi)$" }, size = "850 600" })
hl.window_rule({ match = { class = "^(kprofi)$" }, center = true })

-- Terminal notifications (Dunst replacement)
hl.window_rule({ match = { class = "^(term-notification-.*)$" }, float = true })
hl.window_rule({ match = { class = "^(term-notification-.*)$" }, move = "1650 5" })
hl.window_rule({ match = { class = "^(term-notification-.*)$" }, pin = true })
