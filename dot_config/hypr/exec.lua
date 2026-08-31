local features = require("features")

hl.on("hyprland.start", function()
	hl.exec_cmd("~/.local/bin/wayland-session-env")
	hl.exec_cmd("swayidle -w &")
	hl.exec_cmd("wayland-pipewire-idle-inhibit --wayland --quiet &")
	hl.exec_cmd("foot --server &")
	hl.exec_cmd("mako &")
	hl.exec_cmd("hyprsunset &")
	hl.exec_cmd("clipse -listen &")

	for _, command in ipairs(features.startup) do
		hl.exec_cmd(command)
	end
end)
