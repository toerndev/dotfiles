return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<C-e>", "<cmd>Neotree filesystem toggle reveal left<cr>", desc = "Toggle file tree" },
    },
    opts = {
      window = {
        position = "left",
        width = 30,
      },
      filesystem = {
        follow_current_file = {
          enabled = true, -- auto-track current file when switching buffers
        },
      },
    },
  },
  {
    "stevearc/oil.nvim",
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
    },
    opts = {
      view_options = {
        show_hidden = true,
      },
      skip_confirm_for_simple_edits = true,
    },
  },
  {
    "hedyhli/outline.nvim",
    keys = {
      { "<C-l>", "<cmd>Outline<cr>", desc = "Toggle outline" },
    },
    opts = {},
  },
}
