/* machine settings: begin */
#define DWL_RENDERER "gles2"
#define DWL_RENDER_DEVICE ""
#define DWL_MOUSE_NAME ""
#define DWL_MOUSE_SPEED (0.000000)
#define DWL_XKB_LAYOUT "us,de,tr"
#define DWL_XKB_OPTIONS "grp:alt_shift_toggle"
/* machine settings: end */
/* output rules: begin */
static const MonitorRule monrules[] = {
	{
		.name = "LVDS-1", .mfact = 0.55f, .nmaster = 1, .scale = 1.000000f,
		.lt = &layouts[0], .rr = WL_OUTPUT_TRANSFORM_NORMAL, .x = -1, .y = -1,
		.width = 0, .height = 0, .refresh = 0,
		.image_desc = NULL, .render_format = DRM_FORMAT_XRGB8888,
		.edid = "2742f74b15ea476f9a57389e36b24be4097a1c60e8511d85e50d50d2a71ec65c", .tags = 0, .disabled = 0,
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
