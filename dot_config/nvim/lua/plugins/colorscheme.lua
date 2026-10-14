return {
	{
		"maxmx03/fluoromachine.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			local fm = require("fluoromachine")
			fm.setup({
				glow = true,
				brightness = 0.05,
				theme = "retrowave",
				transparent = true,

				styles = {
					comments = { italic = true },
					functions = { bold = true },
					keywords = { bold = true },
					variables = { italic = true },
					parameters = { italic = true },
				},

			colors = function(_, color)
				local darken = color.darken
				return {
					bg = "#000000",
					bgdark = darken("#000000", 20),
					pink = "#d484fb",
					purple = "#e9c4fd",
					blue = "#99d8fe",
					green = "#30F7BE",
					yellow = "#F8FD00",
					orange = "#F9A429",
					red = "#da3030",
					cyan = "#3bf0f4",
					white = "#e8e8e8",
					black = "#e9c4fd",
					purple2 = "#e8e8e8",
					cyan2 = "#3bf0f4",
					green2 = "#30F7BE",
				}
			end,

				overrides = function(c, color)
					return {
						TelescopeResultsBorder = { fg = c.bgdark, bg = c.bgdark },
						TelescopeResultsNormal = { bg = c.bgdark },
						TelescopePreviewNormal = { bg = c.bg },

						["@comment"] = { italic = true, fg = color.darken(c.purple, 30) },
						["@keyword"] = { fg = c.pink, bold = true },
					}
				end,
				plugins = {
					bufferline = true,
					cmp = true,
					dashboard = true,
					editor = true,
					gitsign = true,
					hop = true,
					ibl = true,
					illuminate = true,
					lazy = true,
					minicursor = true,
					ministarter = true,
					minitabline = true,
					ministatusline = true,
					navic = true,
					neogit = true,
					neotree = true,
					noice = true,
					notify = true,
					lspconfig = true,
					syntax = true,
					telescope = true,
					treesitter = true,
					tree = true,
					wk = true,
				},
			})
			vim.cmd.colorscheme("fluoromachine")
		end,
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "fluoromachine",
		},
	},
}
