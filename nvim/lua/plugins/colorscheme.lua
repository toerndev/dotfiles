return {
  -- Active colorscheme — change lazy=false/config to switch default
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    opts = { style = "wave" },
    config = function(_, opts)
      require("kanagawa").setup(opts)
      vim.cmd.colorscheme("kanagawa-wave")
    end,
  },
  -- Additional colorschemes (lazy-loaded; switch interactively via <leader>ft)
  { "folke/tokyonight.nvim", lazy = true, priority = 1000 },
  { "catppuccin/nvim", name = "catppuccin", lazy = true, priority = 1000 },
  { "rose-pine/neovim", name = "rose-pine", lazy = true, priority = 1000 },
  { "EdenEast/nightfox.nvim", lazy = true, priority = 1000 },
  { "sainnhe/everforest", lazy = true, priority = 1000 },
  { "ellisonleao/gruvbox.nvim", lazy = true, priority = 1000 },
}
