return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  opts = {
    notify_on_error = true,
    formatters_by_ft = {
      -- Fallbacks for projects without biome.json (Biome LSP not attached)
      javascript = { "prettierd", "prettier" },
      javascriptreact = { "prettierd", "prettier" },
      typescript = { "prettierd", "prettier" },
      typescriptreact = { "prettierd", "prettier" },
      json = { "prettierd", "prettier" },
      jsonc = { "prettierd", "prettier" },
      css = { "prettierd", "prettier" },
      graphql = { "prettierd", "prettier" },
      -- Non-JS tooling (never has LSP formatting)
      go = { "goimports" },
      lua = { "stylua" },
      nix = { "nixfmt" },
    },
    formatters = {
      prettierd = {
        condition = function(_, ctx)
          return vim.fs.root(ctx.buf, {
            ".prettierrc", ".prettierrc.json", ".prettierrc.json5",
            ".prettierrc.yaml", ".prettierrc.yml", ".prettierrc.toml",
            ".prettierrc.js", ".prettierrc.cjs", ".prettierrc.mjs",
            "prettier.config.js", "prettier.config.cjs", "prettier.config.mjs", "prettier.config.ts",
          }) ~= nil
        end,
      },
      prettier = {
        condition = function(_, ctx)
          return vim.fs.root(ctx.buf, {
            ".prettierrc", ".prettierrc.json", ".prettierrc.json5",
            ".prettierrc.yaml", ".prettierrc.yml", ".prettierrc.toml",
            ".prettierrc.js", ".prettierrc.cjs", ".prettierrc.mjs",
            "prettier.config.js", "prettier.config.cjs", "prettier.config.mjs", "prettier.config.ts",
          }) ~= nil
        end,
      },
    },
    format_on_save = function(bufnr)
      -- Biome files are handled entirely by the LspAttach autocmd in lsp.lua
      -- (two-pass: lint fixes then whitespace format). Skip conform for those buffers.
      local biome_fmt_fts = {
        javascript = true, javascriptreact = true,
        typescript = true, typescriptreact = true,
        json = true, jsonc = true, css = true,
      }
      local ft = vim.bo[bufnr].filetype
      if #vim.lsp.get_clients({ bufnr = bufnr, name = "biome" }) > 0 and biome_fmt_fts[ft] then
        return nil
      end
      return { timeout_ms = 2000, lsp_format = "never" }
    end,
  },
}
