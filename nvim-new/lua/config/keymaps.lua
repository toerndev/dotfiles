local map = vim.keymap.set

-- Sort selection
map("v", "s", ":sort<CR>", { desc = "Sort selection" })

-- Buffer navigation
map("n", "<C-n>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<C-p>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
