return {
  {
    "echasnovski/mini.icons",
    lazy = false,
    opts = {},
    config = function(_, opts)
      require("mini.icons").setup(opts)
      MiniIcons.mock_nvim_web_devicons()
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { { "overseer" }, "encoding", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      presets = {
        bottom_search = true,       -- keep / and ? at the bottom (less jarring)
        command_palette = true,     -- stack cmdline popup above completion menu
        long_message_to_split = true,
        lsp_doc_border = true,
      },
      lsp = {
        override = {
          -- use treesitter for LSP hover and signature help markdown rendering
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
        },
      },
    },
  },
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      notifier = { enabled = false }, -- noice handles notifications
      lazygit = { enabled = true },
      rename = { enabled = true },
      input = { enabled = true },     -- replaces vim.ui.input (rename prompts, etc.)
      select = { enabled = true },    -- replaces vim.ui.select (code actions, LSP picks, etc.)
    },
    keys = {
      { "<leader>gg", function() Snacks.lazygit() end, desc = "LazyGit" },
      { "<leader>fr", function() Snacks.rename.rename_file() end, desc = "Rename file" },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      spec = {
        { "<leader>c", group = "code" },
        { "<leader>f", group = "file" },
        { "<leader>g", group = "git" },
        { "<leader>o", group = "overseer" },
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer keymaps",
      },
    },
  },
}
