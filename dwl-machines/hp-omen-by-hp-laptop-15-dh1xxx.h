/* machine settings: begin */
#define DWL_RENDERER "vulkan"
#define DWL_RENDER_DEVICE ""
#define DWL_MOUSE_NAME "epic-mouse-v1"
#define DWL_MOUSE_SPEED (-0.500000)
#define DWL_XKB_LAYOUT "us,de,tr"
#define DWL_XKB_OPTIONS "grp:alt_shift_toggle"
/* machine settings: end */
/* output rules: begin */
static const MonitorRule monrules[] = {
	{
		.name = "HDMI-A-1", .mfact = 0.55f, .nmaster = 1, .scale = 2.000000f,
		.lt = &layouts[0], .rr = WL_OUTPUT_TRANSFORM_NORMAL, .x = 0, .y = 0,
		.width = 3840, .height = 2160, .refresh = 60000,
		.image_desc = &bt2020_sdr, .render_format = DRM_FORMAT_XBGR2101010,
		.edid = "b08039357245f181fa52386bee62fbf668b1a4637bbb773c5758a07fc83bf0d9", .tags = 31, .disabled = 0,
	},
	{
		.name = "eDP-1", .mfact = 0.55f, .nmaster = 1, .scale = 1.500000f,
		.lt = &layouts[0], .rr = WL_OUTPUT_TRANSFORM_NORMAL, .x = 1920, .y = 0,
		.width = 1920, .height = 1080, .refresh = 144028,
		.image_desc = NULL, .render_format = DRM_FORMAT_XRGB8888,
		.edid = "4267850cf048ca1967df7fc87a6c4506cdebc1548120098187af8682c336f29d", .tags = 992, .disabled = 0,
	},
	{
		.name = NULL, .mfact = 0.55f, .nmaster = 1, .scale = 1.0f,
		.lt = &layouts[0], .rr = WL_OUTPUT_TRANSFORM_NORMAL, .x = -1, .y = -1,
		.width = 0, .height = 0, .refresh = 0,
		.image_desc = NULL, .render_format = DRM_FORMAT_XRGB8888,
		.edid = NULL, .tags = 0, .disabled = 0,
	},
};
/* output rules: end */
