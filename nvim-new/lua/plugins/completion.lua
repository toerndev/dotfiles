return {
  "saghen/blink.cmp",
  version = "1.*",
  dependencies = {
    "rafamadriz/friendly-snippets", -- snippet collection
    { dir = vim.fn.stdpath("config") .. "/snippets" }, -- custom snippets
  },
  lazy = false,
  opts = {
    keymap = {
      preset = "enter",
      -- select_and_accept works with preselect=false: accepts first item immediately,
      -- or the navigated-to item after C-j/C-k
      ["<Tab>"] = { "select_and_accept", "fallback" },
      ["<C-j>"] = { "select_next", "fallback" },
      ["<C-k>"] = { "select_prev", "fallback" },
    },
    appearance = { nerd_font_variant = "mono" },
    completion = {
      accept = { auto_brackets = { enabled = true } },
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
      list = {
        selection = {
          -- With the enter preset, preselect=true causes Enter to silently accept the
          -- first LSP completion (possibly a multi-line snippet), bypassing indentexpr.
          -- preselect=false: Enter always falls through to indentexpr (4 spaces). ✓
          preselect = false,
        },
      },
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    cmdline = { enabled = false }, -- noice.nvim handles cmdline UI
  },
}
