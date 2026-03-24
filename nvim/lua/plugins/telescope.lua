return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" }, -- native fzf sorter for speed
  },
  cmd = "Telescope",
  keys = {
    { "<C-f>", "<cmd>Telescope find_files<cr>", desc = "Find files" },
    { "<C-S-b>", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
    { "<C-g>", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
    {
      "<leader>ft",
      function()
        local themes = {
          "kanagawa-wave", "kanagawa-dragon", "kanagawa-lotus",
          "tokyonight", "tokyonight-storm", "tokyonight-night", "tokyonight-moon",
          "catppuccin", "catppuccin-latte", "catppuccin-frappe", "catppuccin-macchiato", "catppuccin-mocha",
          "rose-pine", "rose-pine-moon", "rose-pine-dawn",
          "nightfox", "carbonfox", "dayfox", "dawnfox", "duskfox", "nordfox", "terafox",
          "everforest",
          "gruvbox",
        }
        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local conf = require("telescope.config").values
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        local prev, confirmed = vim.g.colors_name, false

        local function apply()
          local e = action_state.get_selected_entry()
          if e then pcall(vim.cmd.colorscheme, e[1]) end
        end

        pickers.new({}, {
          prompt_title = "Colorscheme",
          finder = finders.new_table({ results = themes }),
          sorter = conf.generic_sorter({}),
          attach_mappings = function(prompt_bufnr)
            actions.move_selection_next:enhance({ post = apply })
            actions.move_selection_previous:enhance({ post = apply })
            actions.select_default:replace(function()
              confirmed = true
              actions.close(prompt_bufnr)
              apply()
            end)
            actions.close:enhance({ post = function()
              if not confirmed then pcall(vim.cmd.colorscheme, prev) end
            end })
            return true
          end,
        }):find()
      end,
      desc = "Themes",
    },
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
