return {
	{
		"folke/sidekick.nvim",
		opts = {
			cli = {
				mux = { enabled = false },
				tools = {
					opencode = {
						cmd = { "opencode" },
						env = { OPENCODE_THEME = "dark" },
					},
				},
			},
			nes = { enabled = false },
		},

		keys = {
			{
				"<c-.>",
				function()
					require("sidekick.cli").toggle({ name = "opencode" })
				end,
				desc = "OpenCode",
				mode = { "n", "t", "i", "x" },
			},
			{
				"<leader>af",
				function()
					require("sidekick.cli").send({ msg = "{file}" })
				end,
				desc = "Send File",
			},
			{
				"<leader>as",
				function()
					require("sidekick.cli").send({ msg = "{selection}" })
				end,
				mode = "v",
				desc = "Send Selection",
			},
			{
				"<leader>ab",
				function()
					require("sidekick.cli").send({ msg = "{buffers}" })
				end,
				desc = "Send Buffers",
			},
		},
	},
}
