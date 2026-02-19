return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  -- highlight is built into Neovim 0.11+; indent is still provided by this plugin
  opts = {
    indent = { enable = true },
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
  },
}
