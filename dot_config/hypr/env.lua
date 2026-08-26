-- Cursor
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "28")

-- PATH
local home = assert(os.getenv("HOME"), "HOME is not set")
hl.env("PATH", home .. "/.cargo/bin:" .. home .. "/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl")

-- Qt/GTK Wayland
hl.env("QT_SCREEN_SCALE_FACTORS", "1;1")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- Session type
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Mozilla / Browser
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("MOZ_DBUS_REMOTE", "1")
hl.env("BROWSER", "librewolf")

-- Electron
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
