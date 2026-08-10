-- ============================================================================
-- editor.lua — editor-behaviour overrides
-- ============================================================================
-- Keep editing direct and predictable: no animated scrolling or indent guides.
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

	-- Smart auto-pairing for (), {}, [], "", '', ``:
	--   * typing an opener inserts the closer with the cursor inside
	--   * typing a closer that is already next just moves over it
	--   * <BS> between a pair deletes both; <CR> between {} opens an indented block
	--   * skip_next: no pairing right before a word character (e.g. wrapping)
	--   * skip_ts: no quote-pairing inside strings (apostrophes in text/comments)
	--   * skip_unbalanced: typing ) with more ) than ( inserts nothing extra
	{
		"nvim-mini/mini.pairs",
		enabled = true,
		opts = {
			modes = { insert = true, command = false, terminal = false },
			skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
			skip_ts = { "string" },
			skip_unbalanced = true,
			markdown = true,
		},
	},
}
