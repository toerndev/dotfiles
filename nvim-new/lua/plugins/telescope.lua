return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" }, -- native fzf sorter for speed
  },
  cmd = "Telescope",
  keys = {
    { "<C-f>", "<cmd>Telescope find_files<cr>", desc = "Find files" },
    { "<leader>/", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
    { "<leader>b", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
  },
  config = function()
    local telescope = require("telescope")
    telescope.setup({
      extensions = {
        fzf = {
          fuzzy = true,
          override_generic_sorter = true,
          override_file_sorter = true,
        },
      },
    })
    telescope.load_extension("fzf") -- telescope-fzf-native integration
  end,
}
