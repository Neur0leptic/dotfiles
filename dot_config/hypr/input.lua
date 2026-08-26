hl.config({ input = {
    kb_layout = "us,de,tr",
    kb_variant = "",
    kb_model = "",
    kb_options = "grp:alt_shift_toggle",
    kb_rules = "",
    repeat_rate = 105,
    repeat_delay = 180,
    numlock_by_default = true,
    follow_mouse = 1,
    sensitivity = 0,
    touchpad = {
        natural_scroll = false,
    },
} })

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

hl.config({ cursor = {
    inactive_timeout = 3,
} })
