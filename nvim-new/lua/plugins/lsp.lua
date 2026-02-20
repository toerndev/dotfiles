return {
  {
    "neovim/nvim-lspconfig", -- provides default server configs for vim.lsp.config
    dependencies = {
      "saghen/blink.cmp", -- provides LSP capabilities for completion
    },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      -- Apply a specific biome code action kind (e.g. source.fixAll.biome, source.organizeImports.biome).
      -- context.only filters what the server returns; without it all action kinds come back in one
      -- response, which can cause conflicts. Splitting into separate requests guarantees ordering.
      local function biome_apply_action(client, bufnr, kind)
        local params = {
          textDocument = { uri = vim.uri_from_bufnr(bufnr) },
          range = {
            start = { line = 0, character = 0 },
            ["end"] = { line = vim.api.nvim_buf_line_count(bufnr), character = 0 },
          },
          context = { only = { kind }, diagnostics = {} },
        }
        local result = client:request_sync("textDocument/codeAction", params, 2000, bufnr)
        if result and result.result then
          for _, action in ipairs(result.result) do
            if action.edit then
              vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
            end
          end
        end
      end

      -- Three-pass biome fix+format: lint fixes, then import organization, then whitespace format.
      -- Used by both BufWritePre and <leader>cf/<g=> so they behave identically.
      local function biome_fix_and_format(client, bufnr)
        biome_apply_action(client, bufnr, "source.fixAll.biome")
        biome_apply_action(client, bufnr, "source.organizeImports.biome")
        vim.lsp.buf.format({ async = false, name = "biome", bufnr = bufnr })
      end

      -- biome two-pass if attached, otherwise conform
      local function format_buffer()
        local bufnr = vim.api.nvim_get_current_buf()
        local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "biome" })
        if #clients > 0 then
          biome_fix_and_format(clients[1], bufnr)
        else
          require("conform").format({ lsp_format = "fallback" })
        end
      end

      vim.keymap.set("n", "<leader>cf", format_buffer, { desc = "Format buffer" })

      -- vtsls: TypeScript/JavaScript
      vim.lsp.config("vtsls", {
        capabilities = capabilities,
        settings = {
          vtsls = { autoUseWorkspaceTsdk = true },
          typescript = {
            updateImportsOnFileMove = { enabled = "always" },
          },
        },
      })

      -- biome: diagnostics, lint fixes, and formatting (see BufWritePre autocmd below)
      vim.lsp.config("biome", {
        capabilities = capabilities,
      })

      -- eslint: diagnostics and lint fixes for non-biome projects
      vim.lsp.config("eslint", {
        capabilities = capabilities,
      })

      vim.lsp.enable({ "vtsls", "biome", "eslint" })

      vim.diagnostic.config({ virtual_lines = { current_line = true } })

      -- LSP keymaps (attached per-buffer when an LSP connects)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
          end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "Go to references")
          map("gI", vim.lsp.buf.implementation, "Go to implementation")
          map("gy", vim.lsp.buf.type_definition, "Go to type definition")
          map("K", vim.lsp.buf.hover, "Hover documentation")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          map("g=", format_buffer, "Format buffer (biome or conform)")
          vim.keymap.set("n", "<C-j>", function()
            vim.diagnostic.jump({ count = 1, float = true })
          end, { buffer = event.buf, desc = "Next diagnostic" })
          vim.keymap.set("n", "<C-k>", function()
            vim.diagnostic.jump({ count = -1, float = true })
          end, { buffer = event.buf, desc = "Previous diagnostic" })
        end,
      })

      -- Biome: two-pass BufWritePre — lint fixes first, then whitespace format
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or client.name ~= "biome" then
            return
          end

          vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = args.buf,
            callback = function()
              biome_fix_and_format(client, args.buf)
            end,
          })
        end,
      })

      -- ESLint: apply lint fixes on save (formatting handled by conform/prettier)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or client.name ~= "eslint" then
            return
          end

          vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = args.buf,
            callback = function()
              vim.lsp.buf.code_action({
                context = { only = { "source.fixAll.eslint" }, diagnostics = {} },
                apply = true,
              })
            end,
          })
        end,
      })
    end,
  },
}
