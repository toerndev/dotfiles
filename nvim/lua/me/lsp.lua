-- LSP base configurations

local attach_format_on_save = function(client, bufnr)
   if client.server_capabilities.documentFormattingProvider then
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("Format", { clear = true }),
      buffer = bufnr,
      callback = function() vim.lsp.buf.format({ async = false }) end
    })
  end
end

local lspcfg = {
	capabilities = require("cmp_nvim_lsp").default_capabilities(vim.lsp.protocol.make_client_capabilities()),
	on_attach = function(client, bufnr)
		client.server_capabilities.document_formatting = false
		client.server_capabilities.document_range_formatting = false

		vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

		local ts_utils = require("typescript-tools")
		ts_utils.setup({})

		vim.api.nvim_buf_set_keymap(bufnr, "n", "gs", ":TSToolsOrganizeImports<cr>", { noremap = true })
		vim.api.nvim_buf_set_keymap(bufnr, "n", "gn", ":TSToolsRenameFile<cr>", { noremap = true })
		vim.api.nvim_buf_set_keymap(bufnr, "n", "gm", ":TSToolsAddMissingImports<cr>", { noremap = true })

    attach_format_on_save(client, bufnr)
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
		-- "--tsserver-path",
		tsserver_path,
		"--stdio",
	},
	handlers = lspcfg.handlers,
})

lsp.biome.setup({})

lsp.svelte.setup({
	on_attach = function(client)
		client.server_capabilities.document_formatting = false
	end,
})

lsp.eslint.setup({
	on_attach = lspcfg.on_attach,
	handlers = lspcfg.handlers,
})

lsp.yamlls.setup({
  on_attach = function(client)
    client.server_capabilities.document_formatting = true
		client.server_capabilities.document_range_formatting = true
  end,
  capabilities = vim.lsp.protocol.make_client_capabilities(),
  format = {
    enable = true,
    singleQuote = true,
  },
  validate = true,
  completion = true,
  schemaStore = { enable = true, url = "https://www.schemastore.org/api/json/catalog.json" },
  settings = {
    yaml = {
      customTags = {
        "!fn",
        "!And",
        "!If",
        "!Not",
        "!Equals",
        "!Or",
        "!FindInMap sequence",
        "!Base64",
        "!Cidr",
        "!Ref",
        "!Ref Scalar",
        "!Sub",
        "!GetAtt",
        "!GetAZs",
        "!ImportValue",
        "!Select",
        "!Split",
        "!Join sequence",
      }
    }
  },
  flags = {
    debouce_text_changes = 200
  }
})

lsp.jsonls.setup({
  settings = {
    json = {
      schemas = require('schemastore').json.schemas {
        {
          description = 'AWS CloudFormation provides a common language for you to describe and provision all the infrastructure resources in your cloud environment.',
          fileMatch = {
            '*.cf.json',
          },
          -- url = 'https://raw.githubusercontent.com/awslabs/goformation/master/schema/cloudformation.schema.json'
          url = 'https://d3teyb21fexa9r.cloudfront.net/latest/gzip/CloudFormationResourceSpecification.json'
        },
      },
      validate = { enable = false }
    }
  }
})

lsp.lua_ls.setup({
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


local null_ls = require("null-ls")
local null_helpers = require('null-ls.helpers')

local cfn_lint = ({
  method = null_ls.methods.DIAGNOSTICS,
  filetypes = {'yaml'},
  generator = null_helpers.generator_factory({
    command = "cfn-lint",
    to_stdin = true,
    to_stderr = true,
    args = { "--format", "parseable", "-" },
    format = "line",
    check_exit_code = function(code)
      return code == 0 or code == 255
    end,
    on_output = function(line, params)
      local row, col, end_row, end_col, code, message = line:match(":(%d+):(%d+):(%d+):(%d+):(.*):(.*)")
      local severity = null_helpers.diagnostics.severities['error']

      if message == nil then
        return nil
      end

      if vim.startswith(code, "E") then
        severity = null_helpers.diagnostics.severities['error']
      elseif vim.startswith(code, "W") then
        severity = null_helpers.diagnostics.severities['warning']
      else
        severity = null_helpers.diagnostics.severities['information']
      end

      return {
        message = message,
        code = code,
        row = row,
        col = col,
        end_col = end_col,
        end_row = end_row,
        severity = severity,
        source = "cfn-lint",
      }
    end,
  })
})

null_ls.setup({
  sources =  { null_ls.builtins.diagnostics.cfn_lint }
})
