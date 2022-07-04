--[[
Neovim setup

Check if distro provides plugins before using pip/npm/AUR
e.g. `sudo pacman -S neovim python-neovim python2-neovim`
If not, `python -m pip install neovim`, `npm i -g neovim`.

:checkhealth

Font patching:
  - Ubuntu/gnome-terminal:
    Download nerd font to ~/.fonts
    fc-cache -fv
    gnome-tweaks to set global monospace font

Install Plug:
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

Install using distro package manager:
- fd: install using distro package manager

Install globally with npm:
- typescript-language-server
- vscode-langservers-extracted
- @fsouza/prettierd
- @johnnymorganz/stylua
- typescript

]]

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
Plug('gruvbox-community/gruvbox')
Plug('ryanoasis/vim-devicons')
Plug('nvim-lualine/lualine.nvim')

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
Plug('jose-elias-alvarez/null-ls.nvim')
Plug('jose-elias-alvarez/nvim-lsp-ts-utils')

-- Plugins: generic coding
Plug('tpope/vim-commentary')
Plug('tpope/vim-unimpaired')
Plug('tpope/vim-surround')
Plug('tpope/vim-fugitive')
Plug('NTBBloodbath/rest.nvim')

vim.call('plug#end')
-- } Plugins

-- Style {
vim.cmd('colorscheme gruvbox')
vim.opt.background = 'dark'
-- } Style

-- Configuration: Telescope
vim.cmd('nnoremap <leader>f <cmd>Telescope find_files<cr>')
vim.api.nvim_set_keymap('n', '<leader>b', ':lua require(\'telescope.builtin\').buffers()<cr>', {noremap = true})
vim.api.nvim_set_keymap('n', '<leader>p', ':lua require(\'me.telescope\').find_files_project()<cr>', {noremap = true})
-- vim.cmd('nnoremap <leader>f/ <cmd>Telescope grep_pattern<cr>')
vim.api.nvim_set_keymap('n', '<leader>/', ':lua require(\'me.telescope\').grep_pattern(vim.fn.input(\'Grep for > \'))<cr>', {noremap = true})
--[[
nnoremap <leader>f* :lua require('me.telescope').grep_cword()<cr>
nnoremap <leader>fw :lua require('me.telescope').git_worktree()<cr>
nnoremap <leader>ft :lua require('me.telescope').git_trunk()<cr>
nnoremap <leader>fs :lua require('me.telescope').git_show_qf()<cr>
nnoremap <leader>fy :lua require('me.telescope').search_dotfiles()<cr>
nnoremap <leader>fk :lua require('me.telescope').search_kb()<cr>
nnoremap <leader>bp :lua require('telescope').extensions.file_browser.file_browser()<cr>
nnoremap <leader>fh :lua require('telescope').extensions.file_browser.file_browser({ path=vim.fn.expand("%:p:h")})<cr>

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

-- WIP below
vim.cmd('inoremap <silent><C-k> <C-x><C-o>')

require('me.lualine')
vim.fn.sign_define('LspDiagnosticsSignError', { text='', texthl=lualine_c_diagnostics_error_normal })
vim.fn.sign_define('LspDiagnosticsSignWarning', { text='', texthl=lualine_c_diagnostics_warning_normal })
vim.fn.sign_define('LspDiagnosticsSignInformation', { text='', texthl=lualine_c_diagnostics_info_normal })
vim.fn.sign_define('LspDiagnosticsSignHint', { text='', texthl=lualine_c_diagnostics_info_normal })

-- Diagnostics key bindings
vim.cmd('nnoremap <silent>gj	<cmd>lua vim.diagnostic.goto_next{ wrap = true }<cr>')
vim.cmd('nnoremap <silent>gk	<cmd>lua vim.diagnostic.goto_prev{ wrap = true }<cr>')
vim.cmd('nnoremap <silent>gl	<cmd>lua vim.diagnostic.setloclist()<cr>')
vim.cmd('nnoremap <silent>gq	<cmd>lua vim.diagnostic.setqflist()<cr>')
vim.cmd('nnoremap <silent>L	<cmd>lua vim.diagnostic.open_float({ source = always })<cr>')
vim.diagnostic.config({
  float = {
    format = function(diagnostic)
	return string.format('%s [%s]', diagnostic.message, diagnostic.source == 'eslint' and diagnostic.user_data.lsp.code or diagnostic.source)
    end,
    severity_sort = true,
    close_events = { 'BufLeave', 'CursorMoved', 'InsertEnter', 'FocusLost' },
    max_width = 80,
  },
})

-- Navigation
vim.api.nvim_set_keymap('n', '<Left>', '<<', {noremap = true})
vim.api.nvim_set_keymap('n', '<Right>', '>>', {noremap = true})
vim.api.nvim_set_keymap('v', '<Left>', '<gv', {noremap = true})
vim.api.nvim_set_keymap('v', '<Right>', '>gv', {noremap = true})

vim.cmd('nnoremap <silent>K <cmd>lua vim.lsp.buf.hover()<cr>')
vim.cmd('nnoremap <silent><C-]> <cmd>lua vim.lsp.buf.definition()<cr>')
vim.cmd('nnoremap <silent><C-s> <cmd>lua vim.lsp.buf.signature_help()<cr>')
vim.cmd('nnoremap <silent>gld <cmd>lua vim.lsp.buf.declaration()<cr>')
vim.cmd('nnoremap <silent>gt <cmd>lua vim.lsp.buf.type_definition()<cr>')
vim.cmd('nnoremap <silent>gi <cmd>lua vim.lsp.buf.implementation()<cr>')
vim.cmd('nnoremap <silent>gr <cmd>lua vim.lsp.buf.references()<cr>:copen<cr>')
vim.cmd('nnoremap <silent>glc <cmd>lua vim.lsp.buf.incoming_calls()<cr>:copen<cr>')
vim.cmd('nnoremap <silent>gC <cmd>lua vim.lsp.buf.outgoing_calls()<cr>:copen<cr>')

-- Refactoring
vim.cmd('nnoremap <silent>gw <cmd>lua vim.lsp.buf.rename()<cr>')
vim.cmd('nnoremap <silent>gf <cmd>lua vim.lsp.buf.formatting()<cr>')
vim.cmd('nnoremap <silent>ga <cmd>lua vim.lsp.buf.code_action()<cr>')

vim.cmd('nnoremap <silent>rr <Plug>RestNvim<cr>')

require('me.treesitter')

-- REST client
require("rest-nvim").setup({
  -- Open request results in a horizontal split
  result_split_horizontal = false,
  -- Keep the http file buffer above|left when split horizontal|vertical
  result_split_in_place = false,
  -- Skip SSL verification, useful for unknown certificates
  skip_ssl_verification = false,
  -- Highlight request on run
  highlight = {
    enabled = true,
    timeout = 150,
  },
  result = {
    -- toggle showing URL, HTTP info, headers at top the of result window
    show_url = true,
    show_http_info = true,
    show_headers = true,
  },
  -- Jump to request line on run
  jump_to_request = false,
  env_file = '.env',
  custom_dynamic_variables = {},
  yank_dry_run = true,
})
