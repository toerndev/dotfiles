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
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        always_show_bufferline = false,
        diagnostics = "nvim_lsp",
      },
    },
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = "VeryLazy",
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
        bottom_search = true, -- keep / and ? at the bottom (less jarring)
        command_palette = true, -- stack cmdline popup above completion menu
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
      terminal = { enabled = true },
      input = { enabled = true }, -- replaces vim.ui.input (rename prompts, etc.)
      select = { enabled = true }, -- replaces vim.ui.select (code actions, LSP picks, etc.)
      animate = { enabled = true },
      indent = { enabled = true },
      words = { enabled = true },
      zen = { enabled = true },
    },
    config = function(_, opts)
      require("snacks").setup(opts)
      -- Re-show any open terminals after a window resize so they fit the new
      -- dimensions and keep focus (floating windows don't auto-resize).
      vim.api.nvim_create_autocmd("VimResized", {
        callback = function()
          for _, t in pairs(Snacks.terminal._terminals or {}) do
            if t.win:is_valid() then
              t.win:hide()
              vim.schedule(function()
                t.win:show()
              end)
            end
          end
        end,
      })
    end,
    keys = {
      {
        "<C-\\>",
        function()
          Snacks.terminal()
        end,
        desc = "Toggle terminal",
        mode = { "n", "t" },
      },
      {
        "<C-t>",
        function()
          Snacks.terminal(nil, { count = 2 })
        end,
        desc = "Toggle terminal 2",
        mode = { "n", "t" },
      },
      {
        "<leader>g",
        function()
          Snacks.lazygit()
        end,
        desc = "LazyGit",
      },
      {
        "<leader>fr",
        function()
          Snacks.rename.rename_file()
        end,
        desc = "Rename file",
      },
      {
        "<leader>z",
        function()
          Snacks.zen()
        end,
        desc = "Zen mode",
      },
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
