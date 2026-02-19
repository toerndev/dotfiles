return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  -- highlight and indent are built into Neovim 0.11+, no config needed
  opts = {
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
