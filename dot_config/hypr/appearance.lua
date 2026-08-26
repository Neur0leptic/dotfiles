hl.config({ general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = 2,
    col = {
        active_border = 0xff99d8fe,
        inactive_border = 0xff000000,
    },
    resize_on_border = false,
    allow_tearing = false,
    layout = "dwindle",
} })

hl.config({ decoration = {
    rounding = 5,
    rounding_power = 2,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    shadow = {
        enabled = false,
    },
    blur = {
        enabled = false,
    },
} })

hl.config({ render = {
    direct_scanout = false,
    ctm_animation = false,
    cm_enabled = true,
    new_render_scheduling = false,
} })

hl.config({ ecosystem = {
    no_update_news = true,
    no_donation_nag = true,
} })

hl.config({ misc = {
    force_default_wallpaper = false,
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    key_press_enables_dpms = true,
    mouse_move_enables_dpms = true,
    background_color = 0xff000000,
    disable_scale_notification = true,
    vrr = 0,
    render_unfocused_fps = 0,
    enable_anr_dialog = false,
    allow_session_lock_restore = true,
} })

hl.config({ xwayland = {
    enabled = false,
} })

hl.config({ animations = {
    enabled = false,
} })

hl.config({ dwindle = {
    preserve_split = true,
} })

hl.config({ master = {
    new_status = "master",
} })
