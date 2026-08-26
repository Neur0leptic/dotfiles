return {
	{
		"mason-org/mason.nvim",
		opts = {
			ensure_installed = {
				"bash-language-server",
			},
		},
	},
	{
		"mason-org/mason-lspconfig.nvim",
		opts = {
			ensure_installed = {
				"bashls",
			},
		},
	},
	{
		"neovim/nvim-lspconfig",
		opts = {
			diagnostics = {
				virtual_text = false,
			},
			servers = {
				bashls = {
					settings = {
						bashIde = {
							shellcheckArguments = "-e SC2015,SC2016,SC2086",
						},
					},
				},
			},
		},
		init = function()
			vim.api.nvim_create_autocmd("CursorHold", {
				callback = function()
					vim.diagnostic.open_float({
						focusable = true,
						close_events = {
							"BufLeave",
							"CursorMoved",
							"InsertEnter",
							"FocusLost",
						},
						border = "rounded",
						source = "if_many",
						prefix = " ",
						scope = "cursor",
						header = "",
					})
				end,
			})
		end,
	},
}
