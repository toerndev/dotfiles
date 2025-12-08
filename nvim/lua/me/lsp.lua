-- LSP base configurations

local lspcfg = {
	capabilities = require("cmp_nvim_lsp").default_capabilities(),
	on_attach = function(client, bufnr)
		vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
	end,
	handlers = {
		["textDocument/publishDiagnostics"] = vim.lsp.with(
			vim.lsp.handlers["textDocument/publishDiagnostics"],
			{ virtual_text = false }
		),
	},
}

-- TypeScript / ESLint

-- support yarn PnP if present
local tsserver_path = ".yarn/sdks/typescript/bin/tsserver"
local tsserver_file = io.open(tsserver_path, "r")
if tsserver_file ~= nil then
	io.close(tsserver_file)
else
	tsserver_path = "tsserver"
end

vim.lsp.config('ts_ls', {
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
vim.lsp.enable('ts_ls')

vim.lsp.config('biome', {
  capabilities = lspcfg.capabilities,
  on_attach = function(client, bufnr)
    lspcfg.on_attach(client, bufnr)

    -- Format with fixes
    local function biome_format()
      -- Request code actions ("safe fixes")
      local params = vim.lsp.util.make_range_params(nil, client.offset_encoding)
      params.context = {
        only = { "source.fixAll.biome" },
        diagnostics = {},
      }

      local result = vim.lsp.buf_request_sync(
        bufnr,
        "textDocument/codeAction",
        params,
        1000
      )

      -- Apply code actions synchronously before formatting
      if result then
        for client_id, response in pairs(result) do
          if response.result then
            for _, action in pairs(response.result) do
              if action.edit then
                vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
              end
            end
          end
        end
      end

      -- Format code (indentation, spacing), runs after code actions
      vim.lsp.buf.format({ bufnr = bufnr, timeout_ms = 1000 })
    end

    -- Format on save
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = biome_format,
    })

    -- Manual keybinding (overwrites the default for this buffer)
    vim.keymap.set("n", "gf", biome_format, { buffer = bufnr, desc = "Format with Biome" })
  end,
  handlers = lspcfg.handlers,
})
vim.lsp.enable('biome')

vim.lsp.config('svelte', {
	on_attach = function(client)
		client.server_capabilities.document_formatting = false
	end,
})
vim.lsp.enable('svelte')

vim.lsp.config('eslint', {
	on_attach = lspcfg.on_attach,
	handlers = lspcfg.handlers,
})
vim.lsp.enable('eslint')

vim.lsp.config('yamlls', {
  on_attach = function(client)
    client.server_capabilities.document_formatting = true
		client.server_capabilities.document_range_formatting = true
  end,
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
vim.lsp.enable('yamlls')

vim.lsp.config('jsonls', {
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
vim.lsp.enable('jsonls')

vim.lsp.config('lua_ls', {
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
vim.lsp.enable('lua_ls')


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
