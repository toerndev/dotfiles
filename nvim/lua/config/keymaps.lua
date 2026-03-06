local map = vim.keymap.set

-- Indent/unindent and reselect
map("v", "<", "<gv", { desc = "Unindent selection" })
map("v", ">", ">gv", { desc = "Indent selection" })

-- Sort selection
map("v", "gs", ":sort<CR>", { desc = "Sort selection" })

-- Buffer navigation
map("n", "<C-n>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<C-p>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
