/* Shared settings. The two marked sections are kept separately for each machine. */
#define DWL_CONFIG_VERSION 1
/* machine settings: begin */
#define DWL_RENDERER ""
#define DWL_RENDER_DEVICE ""
#define DWL_MOUSE_NAME ""
#define DWL_MOUSE_SPEED (0.0)
#define DWL_XKB_LAYOUT "us"
#define DWL_XKB_OPTIONS ""
/* machine settings: end */
#define DWL_CURSOR_THEME "catppuccin-mocha-sapphire-cursors"
#define DWL_CURSOR_SIZE 28

/* Taken from https://github.com/djpohly/dwl/issues/466 */
#define COLOR(hex) { ((hex >> 24) & 0xff) / 255.0f, \
	((hex >> 16) & 0xff) / 255.0f, ((hex >> 8) & 0xff) / 255.0f, \
	(hex & 0xff) / 255.0f }

/* appearance */
static const int sloppyfocus = 1;
static const int bypass_surface_visibility = 0;
static const int smartborders = 1;
static const int respect_monitor_reserved_area = 1;
static const int cursor_timeout = 3;
static const unsigned int borderpx = 2;
static const float rootcolor[] = COLOR(0x000000ff);
static const float bordercolor[] = COLOR(0x000000ff);
static const float focuscolor[] = COLOR(0x99d8feff);
static const float urgentcolor[] = COLOR(0xff6c6bff);
static const float fullscreen_bg[] = COLOR(0x000000ff);

/* tagging */
#define TAGCOUNT (10)

/* logging */
static int log_level = WLR_ERROR;

/* x/y: -2 keeps position, -1 centers. w/h: -1 keeps size, (0,1] uses the usable area.
 * A kept size never exceeds DWL_FLOATING_FIT of the usable area, so space remains around it;
 * the windows in DWL_KEEP_SHAPE shrink as a whole to keep their shape. */
#define DWL_FLOATING_FIT 0.90f
#define DWL_KEEP_SHAPE { "vim-wiki-float", NULL }
static const Rule rules[] = {
	/* app_id                 title  tags  float  fullscreen  monitor  x     y     w      h */
	{ "fullscreen",           NULL,  0,    0,     1,          -1,      -2,   -2,   -1,    -1 },
	{ "floating",             NULL,  0,    1,     0,          -1,      -1,   -1,   -1,    -1 },
	{ "vim-wiki-float",       NULL,  0,    1,     0,          -1,      -1,   -1,   -1,    -1 },
	{ "opencode-float",       NULL,  0,    1,     0,          -1,      -1,   -1,   -1,    -1 },
	{ "torrent-float",        NULL,  0,    1,     0,          -1,      -1,   -1,   1000,  600 },
	{ "translator",           NULL,  0,    1,     0,          -1,      -1,   -1,   -1,    -1 },
	{ "clipse",               NULL,  0,    1,     0,          -1,      -1,   -1,   -1,    -1 },
	{ "anki",                 NULL,  0,    1,     0,          -1,      -1,   -1,   700,   600 },
	{ "localsend",            NULL,  0,    1,     0,          -1,      -1,   -1,   400,   700 },
	{ "youtube-info",         NULL,  0,    1,     0,          -1,      -1,   -1,   900,   900 },
	{ "roflix-info",          NULL,  0,    1,     0,          -1,      -1,   -1,   1000,  850 },
	{ "org.roflix.Info",      NULL,  0,    1,     0,          -1,      -1,   -1,   1000,  850 },
	{ "audio-player",         NULL,  0,    1,     0,          -1,      -1,   -1,   800,   500 },
	{ "kprofi",               NULL,  0,    1,     0,          -1,      -1,   -1,   850,   600 },
	{ "term-notification-",   NULL,  0,    1,     0,          -1,      1650, 5,    -1,    -1 },
};

static const Layout layouts[] = {
	{ "[]=", tile },
	{ "><>", NULL },
	{ "[M]", monocle },
};

static struct wlr_output_image_description bt2020_sdr = {
	.primaries = WLR_COLOR_NAMED_PRIMARIES_BT2020,
	.transfer_function = WLR_COLOR_TRANSFER_FUNCTION_SRGB,
	.mastering_luminance = { .min = 0.0, .max = 800.0 },
	.max_cll = 800.0,
	.max_fall = 400.0,
};

/* output rules: begin */
static const MonitorRule monrules[] = {
	{
		.name = NULL, .mfact = 0.55f, .nmaster = 1, .scale = 1.0f,
		.lt = &layouts[0], .rr = WL_OUTPUT_TRANSFORM_NORMAL, .x = -1, .y = -1,
		.width = 0, .height = 0, .refresh = 0,
		.image_desc = NULL, .render_format = DRM_FORMAT_XRGB8888,
		.edid = NULL, .tags = 0, .disabled = 0,
	},
};
/* output rules: end */

static const struct xkb_rule_names xkb_rules = {
	.layout = DWL_XKB_LAYOUT,
	.options = DWL_XKB_OPTIONS,
};
static const int numlock = 1;
static const int capslock = 0;
static const int repeat_rate = 105;
static const int repeat_delay = 180;

/* libinput */
static const int tap_to_click = 1;
static const int tap_and_drag = 1;
static const int drag_lock = 1;
static const int natural_scrolling = 0;
static const int disable_while_typing = 1;
static const int left_handed = 0;
static const int middle_button_emulation = 0;
static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;
static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
static const double accel_speed = 0.0;
static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

#define MODKEY WLR_MODIFIER_LOGO
#define SHCMD(cmd) { .v = (const char *[]) { "/bin/sh", "-c", cmd, NULL } }
#define TAGKEYS(KEY, TAG) \
	{ MODKEY, KEY, view, {.ui = 1u << TAG} }, \
	{ MODKEY|WLR_MODIFIER_SHIFT, KEY, tag, {.ui = 1u << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL, KEY, toggleview, {.ui = 1u << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, KEY, toggletag, {.ui = 1u << TAG} }

static const char *termcmd[] = { "footclient", NULL };
static const char *alttermcmd[] = { "kitty", NULL };
static const char *filecmd[] = { "footclient", "yazi", NULL };
static const char *browsercmd[] = { "librewolf", NULL };
static const char *altbrowsercmd[] = { "/bin/sh", "-c", "if command -v helium-browser >/dev/null 2>&1; then exec helium-browser; else exec helium; fi", NULL };
static const char *kb_notify_cmd[] = { "kb_notify.sh", NULL };

static const Key keys[] = {
	{ MODKEY, XKB_KEY_Return, spawn, {.v = termcmd} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Return, spawn, {.v = alttermcmd} },
	{ MODKEY, XKB_KEY_q, killclient, {0} },
	{ MODKEY, XKB_KEY_Escape, spawn, SHCMD("$HOME/.local/bin/powermenu.sh") },
	{ MODKEY, XKB_KEY_Delete, spawninfo, SHCMD("$HOME/.local/bin/panic_kill.sh") },
	{ MODKEY, XKB_KEY_f, togglefullscreen, {0} },
	{ MODKEY, XKB_KEY_BackSpace, quit, {0} },

	{ MODKEY, XKB_KEY_r, spawn, {.v = filecmd} },
	{ MODKEY, XKB_KEY_d, spawn, SHCMD("rofi -show drun -theme-str 'window { width: 47ch; } configuration { show-icons: true; }'") },
	{ MODKEY, XKB_KEY_space, spawn, SHCMD("$HOME/.local/bin/.script_launcher.sh") },
	{ MODKEY, XKB_KEY_F6, spawn, SHCMD("$HOME/.local/bin/recorder.sh") },
	{ MODKEY, XKB_KEY_w, spawn, {.v = browsercmd} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_w, spawn, {.v = altbrowsercmd} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_a, spawn, SHCMD("footclient -a opencode-float --window-size-chars=110x45 opencode") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_y, spawn, SHCMD("$HOME/.local/bin/helium_launch_webapp.sh 'https://youtube.com' youtube") },
	{ MODKEY, XKB_KEY_c, spawn, SHCMD("footclient nvim \"$HOME/.local/src/dwl/config.h\"") },
	{ MODKEY, XKB_KEY_n, spawn, SHCMD("footclient -a vim-wiki-float --window-size-chars=65x45 nvim -c VimwikiIndex") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_n, spawn, SHCMD("footclient -a fullscreen $HOME/.local/bin/weather.sh") },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_t, spawn, SHCMD("footclient -a translator --window-size-chars=90x30 $HOME/.local/bin/translate.sh") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_t, spawn, SHCMD("footclient -a translator --window-size-chars=90x30 $HOME/.local/bin/trans-fast") },
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, XKB_KEY_t, spawn, SHCMD("$HOME/.local/bin/tesseract.sh") },
	{ MODKEY, XKB_KEY_t, togglefloating, {0} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_v, spawn, SHCMD("footclient -a clipse --window-size-chars=62x32 clipse") },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_y, spawn, SHCMD("$HOME/.local/bin/ytopen.sh") },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_w, spawn, SHCMD("$HOME/.local/bin/wikipedia.sh") },
	{ MODKEY, XKB_KEY_o, focusbrowser, SHCMD("$HOME/.local/bin/wopen.sh") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_c, spawn, SHCMD("footclient -a floating --window-size-chars=75x28 calcurse") },

	{ 0, XKB_KEY_Print, spawn, SHCMD("$HOME/.local/bin/hypr_shot.sh region") },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, XKB_KEY_Print, spawn, SHCMD("$HOME/.local/bin/hypr_shot.sh full") },
	{ WLR_MODIFIER_CTRL, XKB_KEY_Print, spawninfo, SHCMD("$HOME/.local/bin/hypr_shot.sh window") },
	{ WLR_MODIFIER_SHIFT, XKB_KEY_Print, spawn, SHCMD("$HOME/.local/bin/hypr_shot.sh output") },

	{ MODKEY, XKB_KEY_grave, spawn, SHCMD("$HOME/.local/bin/browser_bookmarks.sh") },
	{ 0, XKB_KEY_F1, spawn, SHCMD("$HOME/.local/bin/ybrowser.sh") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_F8, spawn, SHCMD("$HOME/.local/bin/webapp_install.sh") },
	{ MODKEY, XKB_KEY_F1, spawn, SHCMD("dictionary.sh") },
	{ MODKEY, XKB_KEY_F2, spawn, SHCMD("addtorrent.sh") },
	{ MODKEY, XKB_KEY_b, spawn, SHCMD("$HOME/.local/bin/waybar_toggle.sh") },
	{ MODKEY, XKB_KEY_i, spawn, SHCMD("if command -v impala >/dev/null; then footclient -a floating --window-size-chars=80x28 impala; else $HOME/.local/bin/iwctl.sh; fi") },
	{ MODKEY, XKB_KEY_m, spawn, SHCMD("footclient -a floating --window-size-chars=80x28 wiremix") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_m, spawn, SHCMD("command -v cliamp >/dev/null && exec footclient -a floating --window-size-chars=80x28 cliamp") },
	{ MODKEY, XKB_KEY_p, spawn, SHCMD("footclient -a floating --window-size-chars=70x25 bluetui") },
	{ MODKEY, XKB_KEY_s, spawn, SHCMD("footclient -a fullscreen btop") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_s, spawn, SHCMD("footclient -a fullscreen htop") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_l, spawn, SHCMD("localsend") },

	{ MODKEY, XKB_KEY_j, focusstack, {.i = -1} },
	{ MODKEY, XKB_KEY_k, focusstack, {.i = +1} },
	{ WLR_MODIFIER_ALT, XKB_KEY_Tab, focusstack, {.i = +1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_k, movestack, {.i = +1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_j, movestack, {.i = -1} },

	TAGKEYS(XKB_KEY_1, 0),
	TAGKEYS(XKB_KEY_2, 1),
	TAGKEYS(XKB_KEY_3, 2),
	TAGKEYS(XKB_KEY_4, 3),
	TAGKEYS(XKB_KEY_5, 4),
	TAGKEYS(XKB_KEY_6, 5),
	TAGKEYS(XKB_KEY_7, 6),
	TAGKEYS(XKB_KEY_8, 7),
	TAGKEYS(XKB_KEY_9, 8),
	TAGKEYS(XKB_KEY_0, 9),

	{ MODKEY, XKB_KEY_l, resizeactive, {.i = +1} },
	{ MODKEY, XKB_KEY_h, resizeactive, {.i = -1} },
	{ MODKEY, XKB_KEY_Right, resizeactive, {.i = +1} },
	{ MODKEY, XKB_KEY_Left, resizeactive, {.i = -1} },
	{ MODKEY, XKB_KEY_Up, resizeactive, {.i = -2} },
	{ MODKEY, XKB_KEY_Down, resizeactive, {.i = +2} },

	{ 0, XKB_KEY_XF86AudioLowerVolume, spawn, SHCMD("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05- && $HOME/.local/bin/volume.sh") },
	{ 0, XKB_KEY_XF86AudioRaiseVolume, spawn, SHCMD("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 0.05+ && $HOME/.local/bin/volume.sh") },
	{ 0, XKB_KEY_XF86AudioMute, spawn, SHCMD("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && $HOME/.local/bin/volume.sh") },
	{ 0, XKB_KEY_XF86AudioMicMute, spawn, SHCMD("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && $HOME/.local/bin/volume.sh") },
	{ 0, XKB_KEY_XF86MonBrightnessUp, spawn, SHCMD("brightnessctl -e4 -n2 set 5%+ && $HOME/.local/bin/brightness.sh") },
	{ 0, XKB_KEY_XF86MonBrightnessDown, spawn, SHCMD("brightnessctl -e4 -n2 set 5%- && $HOME/.local/bin/brightness.sh") },
	{ LOCKED, XKB_KEY_XF86AudioNext, spawn, SHCMD("playerctl next") },
	{ LOCKED, XKB_KEY_XF86AudioPause, spawn, SHCMD("playerctl play-pause") },
	{ LOCKED, XKB_KEY_XF86AudioPlay, spawn, SHCMD("playerctl play-pause") },
	{ LOCKED, XKB_KEY_XF86AudioPrev, spawn, SHCMD("playerctl previous") },

	{ MODKEY, XKB_KEY_e, spawn, SHCMD("footclient -a fullscreen aerc") },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_k, spawn, SHCMD("$HOME/.local/bin/kprofi.sh") },
	{ MODKEY, XKB_KEY_a, spawn, SHCMD("$HOME/.local/bin/hermes-launch.sh") },

	/* dwl-specific master-stack and output controls */
	{ MODKEY, XKB_KEY_z, zoom, {0} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_Up, incnmaster, {.i = +1} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_Down, incnmaster, {.i = -1} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_space, setlayout, {0} },
	{ MODKEY, XKB_KEY_comma, focusmon, {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY, XKB_KEY_period, focusmon, {.i = WLR_DIRECTION_RIGHT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_comma, tagmon, {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_period, tagmon, {.i = WLR_DIRECTION_RIGHT} },

	{ LOCKED|WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_Terminate_Server, quit, {0} },
#define CHVT(n) { LOCKED|WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_XF86Switch_VT_##n, chvt, {.ui = n} }
	CHVT(1), CHVT(2), CHVT(3), CHVT(4), CHVT(5), CHVT(6),
	CHVT(7), CHVT(8), CHVT(9), CHVT(10), CHVT(11), CHVT(12),
};

static const Button buttons[] = {
	{ MODKEY, BTN_LEFT, moveresize, {.ui = CurMove} },
	{ MODKEY, BTN_RIGHT, moveresize, {.ui = CurResize} },
};
