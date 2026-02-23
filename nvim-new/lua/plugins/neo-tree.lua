return {
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
}
