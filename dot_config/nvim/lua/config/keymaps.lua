-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
vim.api.nvim_set_keymap("n", "<leader>C", ':w! | !compiler.sh "%:p"<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>p", ':!op_out.sh "%:p"<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<C-c>", 'y:call system("wl-copy", @")<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>C", '<cmd>w | !compiler.sh "%:p"<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>p", '<cmd>!op_out.sh "%:p"<CR>', { noremap = true, silent = true })

vim.api.nvim_set_keymap("n", "gw", "gww", { noremap = true })
vim.api.nvim_set_keymap("v", "gw", "gw", { noremap = true })

local function jump_to_placeholder()
	local save_cursor = vim.fn.getcurpos()
	local placeholder_pos = vim.fn.search("<++>", "w")
	if placeholder_pos == 0 then
		vim.fn.setpos(".", save_cursor)
		return
	end

	vim.cmd('normal! "_df>')
	vim.cmd("startinsert")
end

vim.keymap.set({ "n", "i" }, "<A-j>", jump_to_placeholder, { noremap = true, silent = true })
