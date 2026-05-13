local nvim_012 = vim.fn.has("nvim-0.12") == 1

local parsers = {
  "lua",
  "typescript",
  "javascript",
  "tsx",
  "json",
  "markdown",
  "markdown_inline",
  "html",
  "css",
  "graphql",
  "yaml",
  "bash",
}

return {
  "nvim-treesitter/nvim-treesitter",
  -- 'main' requires Neovim 0.12+; highlight/indent are now Neovim built-ins on 0.12+
  -- 'master' is archived but still works on Neovim 0.11
  branch = nvim_012 and "main" or "master",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    if nvim_012 then
      require("nvim-treesitter").setup({ ensure_installed = parsers })
    else
      require("nvim-treesitter.configs").setup({
        ensure_installed = parsers,
        indent = {
          enable = true,
          -- JS/TS indent has known open bugs with arrow functions in callbacks.
          -- $VIMRUNTIME/indent/typescript.vim handles these patterns more reliably.
          disable = { "javascript", "typescript", "tsx", "typescriptreact" },
        },
      })
    end
  end,
}
