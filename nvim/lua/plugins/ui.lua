return {
  {
    "echasnovski/mini.surround",
    event = "VeryLazy",
    opts = {},
  },
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
      git = { enabled = true },
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
      -- Re-show open terminals after a resize so they fit the new dimensions.
      -- Collect all visible terminals first, hide them, then re-show in one
      -- scheduled batch and restore focus to whichever one was active.
      vim.api.nvim_create_autocmd("VimResized", {
        callback = function()
          local current_win = vim.api.nvim_get_current_win()
          local to_restore = {}
          for _, t in pairs(Snacks.terminal._terminals or {}) do
            if t.win:is_valid() then
              table.insert(to_restore, { terminal = t, focused = t.win.win == current_win })
              t.win:hide()
            end
          end
          vim.schedule(function()
            local focus_win = nil
            for _, item in ipairs(to_restore) do
              item.terminal.win:show()
              if item.focused then
                focus_win = item.terminal.win.win
              end
            end
            if focus_win and vim.api.nvim_win_is_valid(focus_win) then
              vim.api.nvim_set_current_win(focus_win)
            end
          end)
        end,
      })
      -- Warn before quitting if overseer tasks or terminal processes are running.
      -- Skip the check when :qa! is used (vim.v.cmdbang == 1).
      vim.api.nvim_create_autocmd("QuitPre", {
        callback = function()
          if vim.v.cmdbang == 1 then
            return
          end
          local warnings = {}
          -- Running overseer tasks
          local ok, overseer = pcall(require, "overseer")
          if ok then
            for _, task in ipairs(overseer.list_tasks({ unique = false })) do
              if task.status == overseer.STATUS.RUNNING then
                table.insert(warnings, "  overseer: " .. task.name)
              end
            end
          end
          -- Terminals with an active foreground process (shell has child processes)
          for id, t in pairs(Snacks.terminal._terminals or {}) do
            if t.buf and vim.api.nvim_buf_is_valid(t.buf) then
              local job_id = vim.b[t.buf].terminal_job_id
              if job_id then
                local pid = vim.fn.jobpid(job_id)
                if pid and pid > 0 then
                  local children = vim.fn.systemlist("pgrep -P " .. pid .. " 2>/dev/null")
                  if #children > 0 then
                    table.insert(warnings, "  terminal " .. id .. " (active process)")
                  end
                end
              end
            end
          end
          if #warnings > 0 then
            local msg = "Background tasks are running:\n"
              .. table.concat(warnings, "\n")
              .. "\n\nQuit anyway?"
            if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
              vim.cmd("throw 'quit cancelled'")
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
        "<leader>gb",
        function()
          Snacks.git.blame_line()
        end,
        desc = "Git blame line",
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
