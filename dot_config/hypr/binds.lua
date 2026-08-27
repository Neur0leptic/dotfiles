-- Launcher commands (keep these first for easy editing)
local T = "footclient"
local K = "kitty"
local FM = "footclient yazi"
local BR = "librewolf"
local ABR = "helium-browser"
local MENU = 'rofi -show drun -theme-str "window { width: 47ch; } configuration { show-icons: true; }"'

-- Modifier (Win-key)
local M = "SUPER"

--  Return        → terminal
hl.bind(M .. " + Return", hl.dsp.exec_cmd(T))
--  ⇧ Return      → alt terminal (kitty)
hl.bind(M .. " + SHIFT + Return", hl.dsp.exec_cmd(K))

--  Q             → kill active window
hl.bind(M .. " + Q", hl.dsp.window.close())
--  Escape        → power menu
hl.bind(M .. " + Escape", hl.dsp.exec_cmd("~/.local/bin/powermenu.sh"))
--  Delete        → panic kill (focused window)
hl.bind(M .. " + Delete", hl.dsp.exec_cmd("~/.local/bin/panic_kill.sh"))
--  F             → fullscreen toggle
hl.bind(M .. " + F", hl.dsp.window.fullscreen())
--  Backspace     → exit Hyprland
hl.bind(M .. " + Backspace", hl.dsp.exit())

--  R             → file manager (yazi)
hl.bind(M .. " + R", hl.dsp.exec_cmd(FM))
--  D             → app launcher (rofi)
hl.bind(M .. " + D", hl.dsp.exec_cmd(MENU))
--  Space         → local script launcher (rofi)
hl.bind(M .. " + Space", hl.dsp.exec_cmd("~/.local/bin/.script_launcher.sh"))
--  F6            → screen recorder
hl.bind(M .. " + F6", hl.dsp.exec_cmd("~/.local/bin/recorder.sh"))
--  W             → browser (librewolf)
hl.bind(M .. " + W", hl.dsp.exec_cmd(BR))
--  ⇧ W           → alt browser (helium)
hl.bind(M .. " + SHIFT + W", hl.dsp.exec_cmd(ABR))

--  ⇧ A           → opencode terminal
hl.bind(M .. " + SHIFT + A", hl.dsp.exec_cmd("footclient -a opencode-float --window-size-chars=110x45 opencode"))
--  ⇧ Y           → YouTube webapp (helium)
hl.bind(
	M .. " + SHIFT + Y",
	hl.dsp.exec_cmd([[ ~/.local/bin/helium_launch_webapp.sh "https://youtube.com" "youtube" ]])
)
--  Y             → YourPipe
hl.bind(M .. " + Y", hl.dsp.exec_cmd("~/.local/bin/yourpipe/bin/yourpipe.sh"))
--  C             → edit hypr config
hl.bind(
	M .. " + C",
	hl.dsp.exec_cmd(
		[[ footclient bash -c 'path="$(ls ~/.config/hypr/*.lua | fzf)" && [ -n "$path" ] && nvim "$path"' ]]
	)
)
--  N             → VimWiki
hl.bind(M .. " + N", hl.dsp.exec_cmd("footclient -a vim-wiki-float --window-size-chars=85x45 nvim -c VimwikiIndex"))
hl.bind(M .. " + SHIFT + N", hl.dsp.exec_cmd("footclient -a fullscreen ~/.local/bin/weather.sh"))
--  Ctrl T        → translator
hl.bind(
	M .. " + CTRL + T",
	hl.dsp.exec_cmd("footclient -a translator --window-size-chars=90x30 ~/.local/bin/translate.sh")
)
-- Shift T  → fast translate (translate-shell)
hl.bind(
	M .. " + SHIFT + T",
	hl.dsp.exec_cmd("footclient -a translator --window-size-chars=90x30 ~/.local/bin/trans-fast")
)
--  Ctrl Shift T  → screen OCR (tesseract)
hl.bind(M .. " + CTRL + SHIFT + T", hl.dsp.exec_cmd("~/.local/bin/tesseract.sh"))
--  T             → toggle float
hl.bind(M .. " + T", hl.dsp.window.float({ action = "toggle" }))
--  Ctrl V        → clipse clipboard
hl.bind(M .. " + CTRL + V", hl.dsp.exec_cmd("footclient -a clipse --window-size-chars=62x32 clipse"))
--  Ctrl Y        → ytopen (YouTube link from clipboard)
hl.bind(M .. " + CTRL + Y", hl.dsp.exec_cmd("~/.local/bin/ytopen.sh"))
--  Ctrl W         → wikipedia (wiki-tui)
hl.bind(M .. " + CTRL + W", hl.dsp.exec_cmd("~/.local/bin/wikipedia.sh"))
--  O             → wopen (clipboard → URL or SearXNG)
hl.bind(M .. " + O", hl.dsp.exec_cmd("~/.local/bin/wopen.sh"))
--  ⇧ C           → calcurse
hl.bind(M .. " + SHIFT + C", hl.dsp.exec_cmd("footclient -a floating --window-size-chars=75x28 calcurse"))

-- Screenshots
hl.bind("PRINT", hl.dsp.exec_cmd("~/.local/bin/hypr_shot.sh region"))
hl.bind("CTRL + SHIFT + PRINT", hl.dsp.exec_cmd("~/.local/bin/hypr_shot.sh full"))
hl.bind("CTRL + PRINT", hl.dsp.exec_cmd("~/.local/bin/hypr_shot.sh window"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("~/.local/bin/hypr_shot.sh output"))

-- Bookmark search / utilities
hl.bind(M .. " + Grave", hl.dsp.exec_cmd("~/.local/bin/browser_bookmarks.sh"))
hl.bind("F1", hl.dsp.exec_cmd("~/.local/bin/ybrowser.sh"))
hl.bind("F8", hl.dsp.exec_cmd("~/.local/bin/webapp_install.sh"))
hl.bind(M .. " + F1", hl.dsp.exec_cmd("dictionary.sh"))
hl.bind(M .. " + F2", hl.dsp.exec_cmd("addtorrent.sh"))
hl.bind(M .. " + B", hl.dsp.exec_cmd("~/.local/bin/waybar_toggle.sh"))
hl.bind(M .. " + I", hl.dsp.exec_cmd("footclient -a floating --window-size-chars=80x28 impala"))
hl.bind(M .. " + M", hl.dsp.exec_cmd("footclient -a floating --window-size-chars=80x28 wiremix"))
hl.bind(M .. " + SHIFT + M", hl.dsp.exec_cmd("footclient -a floating --window-size-chars=80x28 cliamp"))
hl.bind(M .. " + P", hl.dsp.exec_cmd("footclient -a floating --window-size-chars=70x25 bluetui"))
hl.bind(M .. " + S", hl.dsp.exec_cmd("footclient -a fullscreen btop"))
hl.bind(M .. " + SHIFT + S", hl.dsp.exec_cmd("footclient -a fullscreen htop"))
hl.bind(M .. " + SHIFT + L", hl.dsp.exec_cmd("localsend"))

-- Window navigation
hl.bind(M .. " + J", hl.dsp.window.cycle_next({ next = false }))
hl.bind(M .. " + K", hl.dsp.window.cycle_next())
hl.bind("ALT + Tab", function()
	hl.dispatch(hl.dsp.window.cycle_next())
	hl.dispatch(hl.dsp.window.bring_to_top())
end)
hl.bind(M .. " + SHIFT + K", hl.dsp.window.swap({ next = true }))
hl.bind(M .. " + SHIFT + J", hl.dsp.window.swap({ prev = true }))

-- Workspace switching:  + [1-0]
hl.bind(M .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(M .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(M .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(M .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(M .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(M .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(M .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(M .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(M .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(M .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- Move window to workspace:  ⇧ + [1-0]
hl.bind(M .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(M .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(M .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(M .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(M .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(M .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(M .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(M .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(M .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(M .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Special workspace (scratchpad)
hl.bind(M .. " + V", hl.dsp.workspace.toggle_special("magic"))
hl.bind(M .. " + SHIFT + V", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces
hl.bind(M .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(M .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Mouse bindings
hl.bind(M .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(M .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Resize active window (repeatable with key hold)
hl.bind(M .. " + L", hl.dsp.window.resize({ x = 20, y = 0, relative = true }), { repeating = true })
hl.bind(M .. " + H", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })
hl.bind(M .. " + right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }), { repeating = true })
hl.bind(M .. " + left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })
hl.bind(M .. " + up", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true })
hl.bind(M .. " + down", hl.dsp.window.resize({ x = 0, y = 20, relative = true }), { repeating = true })

-- Multimedia keys: volume
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05- && ~/.local/bin/volume.sh")
)
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 0.05+ && ~/.local/bin/volume.sh")
)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && ~/.local/bin/volume.sh"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && ~/.local/bin/volume.sh"))

-- Multimedia keys: brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+ && ~/.local/bin/brightness.sh"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%- && ~/.local/bin/brightness.sh"))

-- Media player controls (locked binds — works even when locked)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Keyboard layout notification (locked bind)
hl.bind("ALT + Shift_L", hl.dsp.exec_cmd("~/.local/bin/kb_notify.sh"), { locked = true })
