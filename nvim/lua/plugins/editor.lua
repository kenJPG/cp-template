-- ============================================================================
-- editor.lua — editor-behaviour overrides
-- ============================================================================
-- Keep editing direct and predictable: no animated scrolling, indent guides,
-- or automatic pair insertion.
-- ============================================================================

return {
	-- LazyVim enables Snacks' animated scrolling. It makes large motions such as
	-- gg and G glide to their destination, which feels like input lag in a GUI.
	{
		"folke/snacks.nvim",
		opts = {
			scroll = { enabled = false },
			indent = { enabled = false },
		},
	},

	-- LazyVim normally enables this; disabling it restores plain Vim insertion.
	{ "nvim-mini/mini.pairs", enabled = false },
}
