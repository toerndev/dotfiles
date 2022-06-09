" Neovim setup
" - No need to build from source since features are provided by plugins!
" - Check if distro provides plugins before using pip/npm/AUR
"   e.g. `sudo pacman -S neovim python-neovim python2-neovim`
"   If not, `python -m pip install neovim`, `npm i -g neovim`.
" - :checkhealth
" - Dependencies: rg, fd
"
" Install Plug:
" curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
"   https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

" Paths {{{
let g:python3_host_prog = '/bin/python'
let g:python_host_prog  = '/bin/python2'
let g:node_host_prog = '$HOME/.n/lib/node_modules/neovim/bin/cli.js'

set dir=~/.local/share/nvim/swap
set undofile
set undodir=~/.local/share/nvim/undo
" }}}

" Global {{{
set nocp
set encoding=utf-8
set ruler
set number
set showtabline=2 " 1=if multiple tabs, 2=always
set synmaxcol=200 cc=100
set expandtab tabstop=2 softtabstop=2 shiftwidth=2
set listchars=tab:➝\ ,

let mapleader=","
let maplocalleader=","

command Reload :source $MYVIMRC
map <leader>ev :e $MYVIMRC<cr>
augroup vimrc
    autocmd! BufWritePost $MYVIMRC source % | echom "Reloaded " . $MYVIMRC | redraw
augroup END

" emacs-style jump to beginning/end of line in insert mode
inoremap <C-a> <C-o>0
inoremap <C-e> <C-o>A
" }}}

call plug#begin()
Plug 'morhetz/gruvbox'
Plug 'ryanoasis/vim-devicons'

" Browser {{{
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-file-browser.nvim'
" }}}

" ??? {{{
" }}}

" LSP & completion {{{
" Dependencies:
"   npm i -g typescript typescript-language-server ts-server
"   vscode-json-language-server yaml-language-server graphql-lsp
"   vscode-html-language-server vscode-css-language-server
"   vscode-eslint-language-server

Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-cmdline'
Plug 'hrsh7th/nvim-cmp'
Plug 'onsails/lspkind-nvim'
Plug 'neovim/nvim-lspconfig'
" }}}

" Generic coding {{{
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-surround'
" }}}

call plug#end()

" Plugin config: Basic {{{
colorscheme gruvbox
" }}}

" Plugin config: Telescope {{{
nnoremap <leader>ff <cmd>Telescope find_files<cr>
"nnoremap <leader>f/ :lua require('me.telescope').grep_pattern(vim.fn.input("Grep for > "))<CR>
"nnoremap <leader>f* :lua require('me.telescope').grep_cword()<CR>
"nnoremap <leader>fb :lua require('telescope.builtin').buffers()<CR>
"nnoremap <leader>fp :lua require('me.telescope').find_files_project()<CR>
"nnoremap <leader>fa :lua require('me.telescope').find_files()<CR>
"nnoremap <leader>fw :lua require('me.telescope').git_worktree()<CR>
"nnoremap <leader>ft :lua require('me.telescope').git_trunk()<CR>
"nnoremap <leader>fs :lua require('me.telescope').git_show_qf()<CR>
"nnoremap <leader>fy :lua require('me.telescope').search_dotfiles()<CR>
"nnoremap <leader>fk :lua require('me.telescope').search_kb()<CR>
""nnoremap <leader>bp :lua require('telescope').extensions.file_browser.file_browser()<CR>
"nnoremap <leader>fh :lua require('telescope').extensions.file_browser.file_browser({ path=vim.fn.expand("%:p:h")})<CR>

" After opening a window to search for a file (or text), just hit enter to open
" the file, or Ctrl-t to open it in a new tab. You can switch tabs with `gt`
" (next tab) or `gT` (previous tab), or `Ngt` where `N` is the tab number
" (starting from 1) to jump immediately to the right tab.  Closing the last
" window in a tab will close the tab itself, so you can just use <leader>c to
" close tabs as well as windows (see window bindings below).
" }}}

" Plugin config: LSP & Completion {{{
lua require('me.cmp')
"   Set completeopt to have a better completion experience
set completeopt=menuone,noinsert,noselect
"   Avoid showing extra message when using completion
set shortmess+=c

" }}}

" File types {{{
autocmd FileType graphql setlocal noexpandtab
" autocmd FileType svelte setlocal commentstring=\/\/\ %s
" }}}
