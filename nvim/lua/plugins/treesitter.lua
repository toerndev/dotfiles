return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master", -- 'main' is a parser-manager-only rewrite; 'master' has the full module system
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        "lua",
        "typescript",
        "javascript",
        "tsx",
        "json",
        "markdown",
        "markdown_inline",
        "html",
        "css",
        "yaml",
        "bash",
      },
      indent = {
        enable = true,
        -- JS/TS indent has known open bugs with arrow functions in callbacks.
        -- $VIMRUNTIME/indent/typescript.vim handles these patterns more reliably.
        disable = { "javascript", "typescript", "tsx", "typescriptreact" },
      },
    })
  end,
}
