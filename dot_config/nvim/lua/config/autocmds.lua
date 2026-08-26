vim.cmd([[
  augroup RestoreCursorShapeOnExit
    autocmd!
    autocmd VimLeave * lua vim.o.guicursor = 'a:ver20'
  augroup END
]])
vim.api.nvim_create_autocmd("VimLeave", {
	pattern = "*.tex",
	command = "!tex_clear.sh %",
})
local function augroup(name)
	return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end
vim.api.nvim_create_autocmd("VimEnter", {
	group = augroup("autoupdate"),
	callback = function()
		if require("lazy.status").has_updates then
			require("lazy").update({ show = false })
		end
	end,
})

vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("custom_wrap_no_spell", { clear = true }),
	pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
	callback = function()
		vim.opt_local.wrap = true
		-- vim.opt_local.spell = true  ← Bu satır YOK, spell kapalı
	end,
})
