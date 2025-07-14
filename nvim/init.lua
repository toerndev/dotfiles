--[[
Neovim setup

Install Plug:
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

Package manager:
- fd (fd-find), ripgrep
- python-neovim, python2-neovim (fallback: `python -m pip install neovim`)
- xclip (X11) or wl-clipboard (Wayland)

npm i -g:
- neovim
- typescript-language-server
- vscode-langservers-extracted
- svelte-language-server
- yaml-language-server
- (@fsouza/prettierd / biome / dprint)
- typescript

lua:
- sumneko/lua-language-server: extract precompiled binaries in ~/.local/lua, add to PATH.
- stylua: cargo install stylua, PATH+=:$HOME/.cargo/bin.

Font patching:
  - Ubuntu/gnome-terminal:
    Download nerd font to ~/.fonts
    fc-cache -fv
    gnome-tweaks to set global monospace font

git:
  - git config --global core.editor "nvim"
]]

-- Paths {
vim.g.python3_host_prog = "/bin/python"
vim.g.python_host_prog = "/bin/python2"
vim.g.node_host_prog = "$HOME/n/lib/node_modules/neovim/bin/cli.js"

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
vim.opt.listchars = { tab = "➝ ", trail = "·" }
vim.opt.list = true
vim.opt.wildignore = { "*/.git/*", "*/node_modules/*" }
vim.opt.hlsearch = false

vim.g.mapleader = ","
vim.g.localleader = ","

vim.cmd("command! Reload :luafile $MYVIMRC")
vim.cmd("command! Config :tabnew $MYVIMRC")
-- } Global

-- Plugins {
local Plug = vim.fn["plug#"]
vim.call("plug#begin", "~/.config/nvim/plugged")

-- Plugins: style
Plug("gruvbox-community/gruvbox")
Plug("ryanoasis/vim-devicons")
Plug("nvim-lualine/lualine.nvim")

-- Plugins: browser
Plug("nvim-lua/plenary.nvim")
Plug("nvim-telescope/telescope.nvim")
Plug("nvim-telescope/telescope-file-browser.nvim")

-- Plugins: LSP + completion
Plug("nvim-treesitter/nvim-treesitter", {
	["do"] = function()
		vim.call(":TSUpdate")
	end,
})
Plug("hrsh7th/cmp-nvim-lsp")
Plug("hrsh7th/cmp-buffer")
Plug("hrsh7th/cmp-path")
Plug("hrsh7th/cmp-cmdline")
Plug("hrsh7th/nvim-cmp")
Plug("onsails/lspkind-nvim")
Plug("neovim/nvim-lspconfig")
Plug("L3MON4D3/LuaSnip")
Plug("saadparwaiz1/cmp_luasnip")
Plug("nvimtools/none-ls.nvim")
Plug("pmizio/typescript-tools.nvim")
Plug("b0o/SchemaStore.nvim")

-- Plugins: generic coding
Plug("tpope/vim-commentary")
Plug("JoosepAlviste/nvim-ts-context-commentstring")
Plug("tpope/vim-unimpaired")
Plug("tpope/vim-surround")
Plug("tpope/vim-fugitive")
Plug("chrisbra/unicode.vim")

-- Plugins: Avante
Plug 'MunifTanjim/nui.nvim'
Plug 'MeanderingProgrammer/render-markdown.nvim'
Plug 'nvim-tree/nvim-web-devicons'
Plug 'zbirenbaum/copilot.lua'
Plug 'stevearc/dressing.nvim'
Plug 'folke/snacks.nvim'
vim.cmd [[
  Plug 'yetone/avante.nvim', { 'branch': 'main', 'do': 'make' }
]]

vim.call("plug#end")
-- } Plugins

-- Style {
vim.cmd("colorscheme gruvbox")
vim.opt.background = "dark"
-- } Style

-- Use mouse selection to copy to clipboard
vim.opt.mouse = "h"

-- Configuration: Telescope
local telescope = require("me.telescope")
vim.cmd("nnoremap <leader>f <cmd>Telescope find_files<cr>")
vim.api.nvim_set_keymap("n", "<leader>C", "", {
	noremap = true,
	callback = function()
		telescope.search_config()
	end,
})
vim.api.nvim_set_keymap("n", "<leader>b", ":lua require('telescope.builtin').buffers()<cr>", { noremap = true })
vim.api.nvim_set_keymap("n", "<leader>p", ":lua require('me.telescope').find_files_project()<cr>", { noremap = true })
-- vim.cmd('nnoremap <leader>f/ <cmd>Telescope grep_pattern<cr>')
function _G.custom_live_grep()
  require('telescope.builtin').live_grep({
    default_text = vim.fn.input('Grep for > '),
    additional_args = function(args)
      table.insert(args, '--glob')
      table.insert(args, '!.git/**')
      table.insert(args, '--glob')
      table.insert(args, '!**/yarn.lock')
      table.insert(args, '--glob')
      table.insert(args, '!**/*.pem')
      table.insert(args, '--glob')
      table.insert(args, '!**/*.excalidrawlib')
      return args
    end
  })
end
vim.api.nvim_set_keymap(
	"n",
	"<leader>/",
  ":lua _G.custom_live_grep()<CR>",
  { noremap = true }
)

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
require("me.cmp")
require("me.lsp")
-- set completeopt to have a better completion experience
vim.opt.completeopt = "menu,menuone,noselect"
-- avoid showing extra message when using completion
vim.opt.shortmess = vim.opt.shortmess + "c"

vim.cmd("autocmd FileType graphql setlocal noexpandtab")

-- emacs-style jump to beginning/end of line in insert mode
vim.cmd("inoremap <C-a> <C-o>0")
vim.cmd("inoremap <C-e> <C-o>A")

-- WIP below
vim.cmd("inoremap <silent><C-k> <C-x><C-o>")

require("me.lualine")
vim.fn.sign_define("LspDiagnosticsSignError", { text = "", texthl = lualine_c_diagnostics_error_normal })
vim.fn.sign_define("LspDiagnosticsSignWarning", { text = "", texthl = lualine_c_diagnostics_warning_normal })
vim.fn.sign_define("LspDiagnosticsSignInformation", { text = "", texthl = lualine_c_diagnostics_info_normal })
vim.fn.sign_define("LspDiagnosticsSignHint", { text = "", texthl = lualine_c_diagnostics_info_normal })

-- Diagnostics key bindings
vim.cmd("nnoremap <silent>gj	<cmd>lua vim.diagnostic.goto_next{ wrap = true }<cr>")
vim.cmd("nnoremap <silent>gk	<cmd>lua vim.diagnostic.goto_prev{ wrap = true }<cr>")
vim.cmd("nnoremap <silent>gl	<cmd>lua vim.diagnostic.setloclist()<cr>")
vim.cmd("nnoremap <silent>gq	<cmd>lua vim.diagnostic.setqflist()<cr>")
vim.cmd("nnoremap <silent>L	<cmd>lua vim.diagnostic.open_float({ source = always })<cr>")
vim.diagnostic.config({
	float = {
		format = function(diagnostic)
			return string.format(
				"%s [%s]",
				diagnostic.message,
				diagnostic.source == "eslint" and diagnostic.user_data.lsp.code or diagnostic.source
			)
		end,
		severity_sort = true,
		close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
		max_width = 80,
	},
})

-- Navigation
vim.api.nvim_set_keymap("n", "<C-p>", ":bprev<cr>", { noremap = true })
vim.api.nvim_set_keymap("n", "<C-n>", ":bnext<cr>", { noremap = true })

vim.api.nvim_set_keymap("n", "<Left>", "<<", { noremap = true })
vim.api.nvim_set_keymap("n", "<Right>", ">>", { noremap = true })
vim.api.nvim_set_keymap("v", "<Left>", "<gv", { noremap = true })
vim.api.nvim_set_keymap("v", "<Right>", ">gv", { noremap = true })

vim.cmd("nnoremap <silent>K <cmd>lua vim.lsp.buf.hover()<cr>")
vim.cmd("nnoremap <silent><C-]> <cmd>lua vim.lsp.buf.definition()<cr>")
vim.cmd("nnoremap <silent><C-s> <cmd>lua vim.lsp.buf.signature_help()<cr>")
vim.cmd("nnoremap <silent>gld <cmd>lua vim.lsp.buf.declaration()<cr>")
vim.cmd("nnoremap <silent>gt <cmd>lua vim.lsp.buf.type_definition()<cr>")
vim.cmd("nnoremap <silent>gi <cmd>lua vim.lsp.buf.implementation()<cr>")
vim.cmd("nnoremap <silent>gr <cmd>lua vim.lsp.buf.references()<cr>:copen<cr>")
vim.cmd("nnoremap <silent>glc <cmd>lua vim.lsp.buf.incoming_calls()<cr>:copen<cr>")
vim.cmd("nnoremap <silent>gC <cmd>lua vim.lsp.buf.outgoing_calls()<cr>:copen<cr>")

-- Refactoring
vim.cmd("nnoremap <silent>gw <cmd>lua vim.lsp.buf.rename()<cr>")
vim.cmd("nnoremap <silent>gf <cmd>lua vim.lsp.buf.format()<cr>")
vim.cmd("nnoremap <silent>ga <cmd>lua vim.lsp.buf.code_action()<cr>")
vim.cmd("nnoremap <C-h> <cmd>lua vim.lsp.buf.hover()<cr>")
vim.cmd("nnoremap <C-i> <cmd>TSLspImportCurrent<cr>")
vim.cmd("vnoremap s :sort<cr>")

vim.cmd("nnoremap <silent>rr <Plug>RestNvim<cr>")

require("me.treesitter")

-- Snippets
require("luasnip.loaders.from_snipmate").lazy_load()

-- Avante
vim.api.nvim_create_autocmd("User", {
  pattern = "avante.nvim",
  callback = function()
    require('avante').setup()
  end
})

-- Render Markdown
require('render-markdown').setup({
  enabled = false
})
vim.keymap.set('n', '<leader>m', '<cmd>RenderMarkdown toggle<cr>', { desc = 'Toggle Render Markdown' })

