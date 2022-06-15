--[[
Neovim setup

No need to build from source since features are provided by plugins!

Check if distro provides plugins before using pip/npm/AUR
e.g. `sudo pacman -S neovim python-neovim python2-neovim`
If not, `python -m pip install neovim`, `npm i -g neovim`.

:checkhealth

Dependencies: rg, ag, fd?

Font patching:
  - Ubuntu/gnome-terminal:
    Download nerd font to ~/.fonts
    fc-cache -fv
    gnome-tweaks to set global monospace font

Install Plug:
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
--]]

-- Paths {
vim.g.python3_host_prog = '/bin/python'
vim.g.python_host_prog  = '/bin/python2'
vim.g.node_host_prog = '$HOME/.n/lib/node_modules/neovim/bin/cli.js'

vim.opt.undofile = true
-- } Paths

-- Global {
vim.opt.number = true
vim.opt.numberwidth = 4
vim.opt.tabstop = 2
vim.opt.shiftwidth = 0 -- match tabstop
vim.opt.expandtab = true
vim.opt.showtabline = 2 -- 1=if multiple tabs, 2=always
-- set synmaxcol=200 cc=100
-- set expandtab tabstop=2 softtabstop=2 shiftwidth=2
vim.opt.listchars = {tab = '➝ ' , trail = '·'}
vim.opt.list = true
vim.opt.wildignore = {'*/.git/*', '*/node_modules/*'}
vim.opt.hlsearch = false

vim.g.mapleader = ','
vim.g.localleader = ','

vim.cmd('command! Reload :luafile $MYVIMRC')
vim.cmd('command! Config :tabnew $MYVIMRC')
vim.api.nvim_create_autocmd('BufWritePost', {
  pattern = vim.env.MYVIMRC,
  command = 'source $MYVIMRC',
})
-- augroup vimrc
--     autocmd! BufWritePost $MYVIMRC source % | echom "Reloaded " . $MYVIMRC | redraw
-- augroup END
--]]

-- } Global

-- Plugins {
local Plug = vim.fn['plug#']
vim.call('plug#begin', '~/.config/nvim/plugged')

-- Plugins: style
Plug('morhetz/gruvbox')
Plug('ryanoasis/vim-devicons')

-- Plugins: browser
Plug('nvim-lua/plenary.nvim')
Plug('nvim-telescope/telescope.nvim')
Plug('nvim-telescope/telescope-file-browser.nvim')

-- Plugins: LSP + completion
Plug('nvim-treesitter/nvim-treesitter', {
  ['do'] = function()
    vim.call(':TSUpdate')
  end
})
Plug('hrsh7th/cmp-nvim-lsp')
Plug('hrsh7th/cmp-buffer')
Plug('hrsh7th/cmp-path')
Plug('hrsh7th/cmp-cmdline')
Plug('hrsh7th/nvim-cmp')
Plug('onsails/lspkind-nvim')
Plug('neovim/nvim-lspconfig')
Plug('L3MON4D3/LuaSnip')
Plug('saadparwaiz1/cmp_luasnip')

-- Plugins: generic coding
Plug('tpope/vim-commentary')
Plug('tpope/vim-unimpaired')
Plug('tpope/vim-surround')
Plug('tpope/vim-fugitive')

vim.call('plug#end')
-- } Plugins

-- Style {
vim.cmd('colorscheme gruvbox')
vim.opt.background = 'dark'
-- } Style

-- Configuration: Telescope
vim.cmd('nnoremap <leader>ff <cmd>Telescope find_files<cr>')
vim.api.nvim_set_keymap('n', '<leader>fp', ':lua require(\'me.telescope\').find_files_project()<cr>', {noremap = true})
-- vim.cmd('nnoremap <leader>f/ <cmd>Telescope grep_pattern<cr>')
vim.api.nvim_set_keymap('n', '<leader>f/', ':lua require(\'me.telescope\').grep_pattern(vim.fn.input(\'Grep for > \'))<cr>', {noremap = true})
--[[
nnoremap <leader>f* :lua require('me.telescope').grep_cword()<CR>
nnoremap <leader>fb :lua require('telescope.builtin').buffers()<CR>
nnoremap <leader>fw :lua require('me.telescope').git_worktree()<CR>
nnoremap <leader>ft :lua require('me.telescope').git_trunk()<CR>
nnoremap <leader>fs :lua require('me.telescope').git_show_qf()<CR>
nnoremap <leader>fy :lua require('me.telescope').search_dotfiles()<CR>
nnoremap <leader>fk :lua require('me.telescope').search_kb()<CR>
nnoremap <leader>bp :lua require('telescope').extensions.file_browser.file_browser()<CR>
nnoremap <leader>fh :lua require('telescope').extensions.file_browser.file_browser({ path=vim.fn.expand("%:p:h")})<CR>

After opening a window to search for a file (or text), just hit enter to open
the file, or Ctrl-t to open it in a new tab. You can switch tabs with `gt`
(next tab) or `gT` (previous tab), or `Ngt` where `N` is the tab number
(starting from 1) to jump immediately to the right tab.  Closing the last
window in a tab will close the tab itself, so you can just use <leader>c to
close tabs as well as windows (see window bindings below).
--]]

-- Configuration: nvim-cmp
require('me.cmp')
require('me.lsp')
-- set completeopt to have a better completion experience
vim.opt.completeopt = 'menu,menuone,noselect'
-- avoid showing extra message when using completion
vim.opt.shortmess = vim.opt.shortmess + 'c'

vim.cmd('autocmd FileType graphql setlocal noexpandtab')

-- emacs-style jump to beginning/end of line in insert mode
vim.cmd('inoremap <C-a> <C-o>0')
vim.cmd('inoremap <C-e> <C-o>A')
