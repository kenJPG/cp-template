-- ============================================================================
-- noice.lua — keep routine saves out of the top mini view
-- ============================================================================

return {
	{
		"folke/noice.nvim",
		opts = function(_, opts)
			opts.lsp = opts.lsp or {}
			opts.lsp.progress = opts.lsp.progress or {}
			opts.lsp.progress.enabled = false

			opts.routes = opts.routes or {}
			table.insert(opts.routes, 1, {
				filter = { event = "msg_show", find = "written" },
				opts = { skip = true },
			})
		end,
	},
}
