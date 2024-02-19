require("nvim-treesitter.configs").setup({
	ensure_installed = { "http", "javascript", "json", "typescript", "svelte" },
	highlight = {
		enable = true,
		disable = { "yaml" },
	},
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "gnn",
			node_incremental = "grn",
			scope_incremental = "grc",
			node_decremental = "grm",
		},
	},
	-- indentation problems with multiple languages, turn off
	indent = { enable = false },
})
