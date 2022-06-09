-- LSP base configurations
local lspcfg = {
	capabilities = require("cmp_nvim_lsp").update_capabilities(vim.lsp.protocol.make_client_capabilities()),
	on_attach = function(client, bufnr)
		client.resolved_capabilities.document_formatting = false
		vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
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
    'typescript-language-server',
    '--tsserver-path',
    tsserver_path,
    '--stdio'
  },
  handlers = lspcfg.handlers,
})

lsp.eslint.setup({
  on_attach = lspcfg.on_attach,
  handlers = lspcfg.handlers,
})
