let mapleader =","

if ! filereadable(system('echo -n "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/autoload/plug.vim"'))
	echo "Downloading junegunn/vim-plug to manage plugins..."
	silent !mkdir -p ${XDG_CONFIG_HOME:-$HOME/.config}/nvim/autoload/
	silent !curl "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" > ${XDG_CONFIG_HOME:-$HOME/.config}/nvim/autoload/plug.vim
	autocmd VimEnter * PlugInstall
endif

map ,, :keepp /<++><CR>ca<
imap ,, <esc>:keepp /<++><CR>ca<

call plug#begin(system('echo -n "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/plugged"'))
 Plug 'tpope/vim-surround'
 Plug 'preservim/nerdtree'
 Plug 'vimwiki/vimwiki'
 Plug 'tpope/vim-commentary'
 Plug 'dylanaraps/wal.vim'
 Plug 'neoclide/coc.nvim'
call plug#end()

set notitle
set go=a
set mouse=a
set nohlsearch
set clipboard=
set noshowmode
set noruler
set laststatus=0
set noshowcmd

" Some basics:
	nnoremap c "_c
	set nocompatible
	filetype plugin on
	filetype indent on
	syntax on
	set encoding=utf-8
	set nonumber
" Enable autocompletion:
	set wildmode=longest,list,full
" Disables automatic commenting on newline:
	autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o
" Perform dot commands over visual beams:
	vnoremap . :normal .<CR>
" Goyo plugin makes text more readable when writing prose:
	map <leader>f :Goyo \| set bg=dark \| set linebreak<CR>
" Spell-check set to <leader>o, 'o' for 'orthography':
	map <leader>o :setlocal spell! spelllang=en_us<CR>
" Splits open at the bottom and right, which is non-retarded, unlike vim defaults.
	set splitbelow splitright
" Nerd tree
	map <leader>n :NERDTreeToggle<CR>
	autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
    if has('nvim')
        let NERDTreeBookmarksFile = stdpath('data') . '/NERDTreeBookmarks'
    else
        let NERDTreeBookmarksFile = '~/.vim' . '/NERDTreeBookmarks'
    endif

" vimling:
	nm <leader>d :call ToggleDeadKeys()<CR>
	imap <leader>d <esc>:call ToggleDeadKeys()<CR>a
	nm <leader>i :call ToggleIPA()<CR>
	imap <leader>i <esc>:call ToggleIPA()<CR>a
	nm <leader>q :call ToggleProse()<CR>
" Shortcutting split navigation, saving a keypress:
	map <C-h> <C-w>h
	map <C-j> <C-w>j
	map <C-k> <C-w>k
	map <C-l> <C-w>l

" Replace ex mode with gq
	map Q gq

" Open my bibliography file in split
	map <leader>b :vsp<space>$BIB<CR>
	map <leader>r :vsp<space>$REFER<CR>

" Replace all is aliased to S.
	nnoremap S :%s//g<Left><Left>

" Compile document, be it groff/LaTeX/markdown/etc.
	map <leader>c :w! \| !compiler.sh "%:p"<CR>

" Open corresponding .pdf/.html or preview
	map <leader>p :!op_out.sh "%:p"<CR>

" Runs a script that cleans out tex build files whenever I close out of a .tex file.
	autocmd VimLeave *.tex !tex_clear.sh %

vnoremap <C-c> y:call system("wl-copy", @")<CR>

" Ensure files are read as what I want:
	let g:vimwiki_ext2syntax = {'.Rmd': 'markdown', '.rmd': 'markdown','.md': 'markdown', '.markdown': 'markdown', '.mdown': 'markdown'}
	map <leader>v :VimwikiIndex<CR>
	let g:vimwiki_list = [{'path': '~/.local/share/nvim/vimwiki', 'syntax': 'markdown', 'ext': '.md'}]
	autocmd BufRead,BufNewFile /tmp/calcurse*,~/.calcurse/notes/* set filetype=markdown
	autocmd BufRead,BufNewFile *.ms,*.me,*.mom,*.man set filetype=groff
	autocmd BufRead,BufNewFile *.tex set filetype=tex

" Save file as doas on files that require root permission
	cabbrev w!! execute 'silent! write !doas tee % >/dev/null' <bar> edit!

" Automatically deletes all trailing whitespace and newlines at end of file on save. & reset cursor position
 	autocmd BufWritePre * let currPos = getpos(".")
	autocmd BufWritePre * %s/\s\+$//e
	autocmd BufWritePre * %s/\n\+\%$//e
	autocmd BufWritePre *.[ch] %s/\%$/\r/e
  	autocmd BufWritePre * cal cursor(currPos[1], currPos[2])

" Turns off highlighting on the bits of code that are changed, so the line that is changed is highlighted but the actual text that has changed stands out on the line and is readable.
if &diff
    highlight! link DiffText MatchParen
endif
" Function for toggling the bottom statusbar:
nnoremap <leader>h :call ToggleHiddenAll()<CR>
set fillchars=fold:\ ,vert:\│,eob:\ ,msgsep:‾
" Load command shortcuts generated from bm-dirs and bm-files via shortcuts script.
" Here leader is ";".
" So ":vs ;cfz" will expand into ":vs /home/<user>/.config/zsh/.zshrc"
" if typed fast without the timeout.
set rtp+=/usr/share/vim/vimfiles

" latex
autocmd FileType tex nnoremap tb i\textbf{}<Esc>i
autocmd FileType tex nnoremap ct i\textcite{}<Esc>i
autocmd FileType tex nnoremap cp i\parencite{}<Esc>i
autocmd FileType tex nnoremap cha i\chapter{}<Esc>i
autocmd FileType tex nnoremap sec i\section{}<Esc>i
" autocmd FileType tex nnoremap hl i\textcolor{hlcl}{}<Esc>i
" autocmd FileType tex nnoremap min i\begin{minted}{bash}<CR><CR>\end{minted}<Esc>kA
autocmd FileType tex nnoremap min i{<CR><BS>\color{codefg}<CR>\begin{minted}{bash}<CR><CR>\end{minted}<CR>}<Esc>kkA
autocmd FileType tex nnoremap hl i\textcolor{hlcl}{\texttt{}}<Esc>F{a

colorscheme wal

let &t_8f="\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b="\<Esc>[48;2;%lu;%lu;%lum"
set termguicolors

highlight LineNr guibg=none guifg=#616161
highlight IncSearch guifg=#FFFFFF guibg=#000000
highlight MatchParen guifg=#000000 guibg=#FFFFFF cterm=bold

" COC settings
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#_select_confirm() :
      \ coc#expandableOrJumpable() ? "\<C-r>=coc#rpc#request('doKeymap', ['snippets-expand-jump',''])\<CR>" :
      \ CheckBackspace() ? "\<TAB>" :
      \ coc#refresh()

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

let g:coc_snippet_next = '<tab>'

" Use <C-l> for trigger snippet expand.
imap <C-l> <Plug>(coc-snippets-expand)

" Use <C-j> for select text for visual placeholder of snippet.
vmap <C-j> <Plug>(coc-snippets-select)

" Use <C-j> for jump to next placeholder, it's default of coc.nvim
let g:coc_snippet_next = '<c-j>'

" Use <C-k> for jump to previous placeholder, it's default of coc.nvim
let g:coc_snippet_prev = '<c-k>'

" Use <C-j> for both expand and jump (make expand higher priority.)
imap <C-j> <Plug>(coc-snippets-expand-jump)

" Use <leader>x for convert visual selected code to snippet
xmap <leader>x  <Plug>(coc-convert-snippet)

nnoremap <silent><nowait><expr> <C-j> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-j>"
nnoremap <silent><nowait><expr> <C-k> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-k>"
inoremap <silent><nowait><expr> <C-j> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "\<Right>"
inoremap <silent><nowait><expr> <C-k> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "\<Left>"

nmap <silent> <c-]> :call CocAction('diagnosticNext')<cr>
nmap <silent> <c-[> :call CocAction('diagnosticPrevious')<cr>

augroup RestoreCursorShapeOnExit
    autocmd!
    autocmd VimLeave * set guicursor=a:ver20
augroup END

function! CompileAndRestartDwl()
    execute 'cd ${HOME}/.local/src/dwl/'

    let compile_cmd = 'CC=clang CFLAGS="-O3 -flto=thin -march=native -pipe" LDFLAGS="-fuse-ld=mold -flto=thin -rtlib=compiler-rt -unwindlib=libunwind -Wl,-O3 -Wl,--as-needed" make'
    call system(compile_cmd)

    let install_cmd = 'doas make install'
    call system(install_cmd)

    call system('pkill dwl')
endfunction

" augroup AutoCompileDwl
"     autocmd!
"     autocmd BufWritePost ${HOME}/.local/src/dwl/config.h call CompileAndRestartDwl()
augroup END
