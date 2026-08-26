require("config.lazy")

vim.diagnostic.config({ virtual_text = false })

local conform = require("conform")
conform.setup({
	formatters = {
		shfmt = {
			command = "shfmt",
			args = { "-i", "8", "-ci", "-sr" },
			stdin = true,
		},
	},
	format_on_save = {
		timeout_ms = 1000,
		lsp_fallback = true,
	},
})
vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = { "*.sh" },
	callback = function()
		conform.format({ async = false, timeout_ms = 1000 })
	end,
})
