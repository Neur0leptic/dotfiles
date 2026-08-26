return {
	{
		"vimwiki/vimwiki",
		init = function()
			vim.g.vimwiki_list = {
				{
					path = "~/vimwiki/",
					syntax = "markdown",
					ext = ".md",
				},
			}
			vim.g.vimwiki_global_ext = 0

			-- OKUNAKLILIK AYARLARI
			vim.g.vimwiki_hl_headers = 1 -- Başlıkları renklendir
			vim.g.vimwiki_hl_cb_checked = 1 -- İşaretli checkbox'ları highlight yap

			-- Conceal ayarları (gizleme)
			vim.g.vimwiki_conceallevel = 2 -- Link'leri güzelleştir
			vim.g.vimwiki_conceal_onechar_markers = 1 -- Bold/italic işaretlerini gizle
			vim.g.vimwiki_conceal_pre = 1 -- Kod bloklarını düzelt

			-- Tablo ayarları
			vim.g.vimwiki_table_auto_fmt = 1 -- Tabloları otomatik formatla
			vim.g.vimwiki_table_reduce_last_col = 0 -- Son sütunu küçültme

			-- Folding (katlama)
			vim.g.vimwiki_folding = "expr" -- Başlıkları katla

			-- Kod bloğu highlighting
			vim.g.vimwiki_automatic_nested_syntaxes = 1 -- Kod bloklarında syntax highlight

			-- Başlık renkleri özelleştirme
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "vimwiki",
				callback = function()
					-- Başlık renkleri
					vim.cmd([[
						highlight VimwikiHeader1 guifg=#FF6188 gui=bold ctermfg=Red cterm=bold
						highlight VimwikiHeader2 guifg=#A9DC76 gui=bold ctermfg=Green cterm=bold
						highlight VimwikiHeader3 guifg=#78DCE8 gui=bold ctermfg=Cyan cterm=bold
						highlight VimwikiHeader4 guifg=#FFD866 gui=bold ctermfg=Yellow cterm=bold
						highlight VimwikiHeader5 guifg=#AB9DF2 gui=bold ctermfg=Magenta cterm=bold
						highlight VimwikiHeader6 guifg=#FC9867 gui=bold ctermfg=Blue cterm=bold

						" Link renkleri
						highlight VimwikiLink guifg=#78DCE8 gui=underline ctermfg=Cyan cterm=underline

						" Bold ve Italic
						highlight VimwikiBold gui=bold cterm=bold
						highlight VimwikiItalic gui=italic cterm=italic

						" Checkbox
						highlight VimwikiTodo guifg=#FFD866 ctermfg=Yellow
						highlight VimwikiCheckBoxDone guifg=#676E95 gui=strikethrough ctermfg=DarkGray cterm=strikethrough

						" Kod blokları
						highlight VimwikiCode guibg=#1E1E2E guifg=#C9D1D9 ctermbg=DarkGray ctermfg=White
						highlight VimwikiPre guibg=#1E1E2E ctermbg=DarkGray
					]])
				end,
			})
		end,
	},
}
