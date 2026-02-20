return {
  "stevearc/overseer.nvim",
  cmd = { "OverseerToggle", "OverseerRun", "OverseerOpen" },
  keys = {
    { "<leader>oo", "<cmd>OverseerToggle<cr>", desc = "Task list" },
    {
      "<leader>od",
      function()
        require("overseer").new_task({ cmd = { "yarn", "dev" } }):start()
      end,
      desc = "yarn dev",
    },
  },
  opts = {},
}
