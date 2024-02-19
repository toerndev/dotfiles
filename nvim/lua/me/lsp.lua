-- LSP base configurations

local lspcfg = {
	capabilities = require("cmp_nvim_lsp").default_capabilities(vim.lsp.protocol.make_client_capabilities()),
	on_attach = function(client, bufnr)
		client.server_capabilities.document_formatting = false
		client.server_capabilities.document_range_formatting = false

		vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

		local ts_utils = require("nvim-lsp-ts-utils")
		ts_utils.setup({})
		ts_utils.setup_client(client)

		vim.api.nvim_buf_set_keymap(bufnr, "n", "gs", ":TSLspOrganize<cr>", { noremap = true })
		vim.api.nvim_buf_set_keymap(bufnr, "n", "gn", ":TSLspRenameFile<cr>", { noremap = true })
		vim.api.nvim_buf_set_keymap(bufnr, "n", "gm", ":TSLspImportAll<cr>", { noremap = true })
	end,
	handlers = {
		["textDocument/publishDiagnostics"] = vim.lsp.with(
			vim.lsp.diagnostic.on_publish_diagnostics,
			{ virtual_text = false }
		),
	},
}

-- TypeScript / ESLint
local lsp = require("lspconfig")

-- support yarn PnP if present
local tsserver_path = ".yarn/sdks/typescript/bin/tsserver"
local tsserver_file = io.open(tsserver_path, "r")
if tsserver_file ~= nil then
	io.close(tsserver_file)
else
	tsserver_path = "tsserver"
end

lsp.tsserver.setup({
	capabilities = lspcfg.capabilities,
	on_attach = lspcfg.on_attach,
	cmd = {
		"typescript-language-server",
		"--tsserver-path",
		tsserver_path,
		"--stdio",
	},
	handlers = lspcfg.handlers,
})

lsp.svelte.setup({
	on_attach = function(client)
		client.server_capabilities.document_formatting = false
	end,
})

lsp.eslint.setup({
	on_attach = lspcfg.on_attach,
	handlers = lspcfg.handlers,
})

local null_ls = require("null-ls")
local null_ls_utils = require("null-ls.utils")
local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
null_ls.setup({
	debug = true,
	-- debounce = 250,
	sources = {
		null_ls.builtins.formatting.dprint.with({
			filetypes = {
				"css",
				"graphql",
				"graphqls",
				"html",
				"javascript",
				"javascriptreact",
				-- "json",
				"markdown",
				-- "svelte",
				"toml",
				"typescript",
				"typescriptreact",
				"yaml",
			},
		}),
		null_ls.builtins.formatting.prettierd.with({
			PRETTIERD_LOCAL_PRETTIER_ONLY = 1,
			filetypes = {
				"svelte",
			},
		}),
		-- null_ls.builtins.diagnostics.eslint,
		-- null_ls.builtins.code_actions.eslint,
		null_ls.builtins.formatting.trim_whitespace,
		null_ls.builtins.formatting.stylua,
	},
	on_attach = function(client, bufnr)
		if client.supports_method("textDocument/formatting") then
			vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = augroup,
				buffer = bufnr,
				callback = function()
					vim.lsp.buf.format({ bufnr = bufnr })
				end,
			})
		end
	end,
	root_dir = null_ls_utils.root_pattern(".git"),
})

require("lspconfig").lua_ls.setup({
	on_attach = function(client)
		client.server_capabilities.document_formatting = false
		client.server_capabilities.document_range_formatting = false
	end,
	settings = {
		Lua = {
			runtime = {
				-- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
				version = "LuaJIT",
				workspace = { checkThirdParty = false },
				telemetry = { enable = false },
			},
			diagnostics = {
				-- Get the language server to recognize the `vim` global
				globals = {
					"vim",
					"lualine_c_diagnostics_error_normal",
					"lualine_c_diagnostics_warning_normal",
					"lualine_c_diagnostics_info_normal",
					"lualine_c_diagnostics_info_normal",
				},
			},
			workspace = {
				-- Make the server aware of Neovim runtime files
				library = vim.api.nvim_get_runtime_file("", true),
			},
			-- Do not send telemetry data containing a randomized but unique identifier
			telemetry = {
				enable = false,
			},
		},
	},
})
