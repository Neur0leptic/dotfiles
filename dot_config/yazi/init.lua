require("git"):setup()

local filesystem_usage = ""
local filesystem_cwd = ""

local function refresh_filesystem_usage()
	local cwd = tostring(cx.active.current.cwd)
	if cwd == filesystem_cwd then
		return
	end

	local handle = io.popen("df -B1 --output=size,used,avail " .. ya.quote(cwd) .. " 2>/dev/null")
	if not handle then
		return
	end

	local output = handle:read("*a")
	handle:close()

	local total, used, free = output:match("(%d+)%s+(%d+)%s+(%d+)%s*$")
	if total then
		filesystem_cwd = cwd
		filesystem_usage = string.format(
			"Total %s | Used %s | Free %s",
			ya.readable_size(tonumber(total)),
			ya.readable_size(tonumber(used)),
			ya.readable_size(tonumber(free))
		)
	end
end

local yatline = require("yatline")

Yatline.string.get.filesystem_usage = function()
	refresh_filesystem_usage()
	return filesystem_usage
end

yatline:setup({
	section_separator = { open = "", close = "" },
	part_separator = { open = "", close = "" },
	inverse_separator = { open = "", close = "" },

	style_a = {
		fg = "#000000",
		bg_mode = {
			normal = "#57ECFC",
			select = "#35F9A9",
			un_set = "#BEA9FE",
		},
	},
	style_b = { bg = "#F4FE00", fg = "#000000" },
	style_c = { bg = "#000000", fg = "#F8F8F8" },

	permissions_t_fg = "#35F9A9",
	permissions_r_fg = "#F4FE00",
	permissions_w_fg = "#FEC4BF",
	permissions_x_fg = "#57ECFC",
	permissions_s_fg = "#F8F8F8",

	tab_width = 20,

	selected = { icon = "󰻭", fg = "#F4FE00" },
	copied = { icon = "", fg = "#35F9A9" },
	cut = { icon = "", fg = "#FEC4BF" },

	total = { icon = "󰮍", fg = "#F4FE00" },
	succ = { icon = "", fg = "#35F9A9" },
	fail = { icon = "", fg = "#FEC4BF" },

	show_background = true,
	display_header_line = true,
	display_status_line = true,

	component_positions = { "header", "tab", "status" },

	header_line = {
		left = {
			section_a = {
				{ type = "line", name = "tabs", params = { "left" } },
			},
			section_b = {},
			section_c = {
				{ type = "string", name = "filesystem_usage" },
			},
		},
		right = {
			section_a = {
				{ type = "string", name = "date", params = { "%A, %d %B %Y" } },
			},
			section_b = {
				{ type = "string", name = "date", params = { "%X" } },
			},
			section_c = {},
		},
	},

	status_line = {
		left = {
			section_a = {
				{ type = "string", name = "tab_mode" },
			},
			section_b = {
				{ type = "string", name = "hovered_size" },
			},
			section_c = {
				{ type = "string", name = "hovered_path" },
				{ type = "coloreds", name = "count" },
			},
		},
		right = {
			section_a = {
				{ type = "coloreds", name = "githead" },
			},
			section_b = {
				{ type = "string", name = "cursor_position" },
				{ type = "string", name = "cursor_percentage" },
			},
			section_c = {
				{ type = "string", name = "hovered_file_extension", params = { true } },
				{ type = "coloreds", name = "permissions" },
			},
		},
	},
})

require("yatline-githead"):setup({
	order = { "branch", "remote", "staged", "unstaged", "untracked" },
})

function Linemode:size_and_mtime()
	local time = math.floor(self._file.cha.mtime or 0)
	if time == 0 then
		time = ""
	elseif os.date("%Y", time) == os.date("%Y") then
		time = os.date("%b %d %H:%M", time)
	else
		time = os.date("%b %d  %Y", time)
	end
	local size = self._file:size()
	return string.format("%s %s", size and ya.readable_size(size) or "-", time)
end
