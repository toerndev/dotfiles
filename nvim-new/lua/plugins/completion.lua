return {
  "saghen/blink.cmp",
  version = "1.*",
  dependencies = {
    "rafamadriz/friendly-snippets", -- snippet collection
  },
  event = "InsertEnter",
  opts = {
    keymap = { preset = "enter" },
    appearance = { nerd_font_variant = "mono" },
    completion = {
      accept = { auto_brackets = { enabled = true } },
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    cmdline = { enabled = true },
  },
}
