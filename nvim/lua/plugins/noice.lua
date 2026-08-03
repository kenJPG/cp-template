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
			table.insert(opts.routes, {
				filter = { event = "msg_show", kind = "", find = "written" },
				opts = { skip = true },
			})
		end,
	},
}
