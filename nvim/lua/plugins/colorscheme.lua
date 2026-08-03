-- ============================================================================
-- colorscheme.lua — classic native gVim colors
-- ============================================================================
-- Neovim's built-in "vim" scheme restores the classic Vim/gVim syntax palette.
-- It needs no plugin and follows the light background set in options.lua.
-- ============================================================================

local function clear_gutter_backgrounds()
	for _, group in ipairs({
		"SignColumn",
		"FoldColumn",
		"LineNr",
		"CursorLineSign",
		"CursorLineFold",
		"CursorLineNr",
	}) do
		vim.cmd(("highlight %s guibg=NONE ctermbg=NONE"):format(group))
	end
end

return {
	{
		"LazyVim/LazyVim",
		init = function()
			local group = vim.api.nvim_create_augroup("cp_template_gutter_background", { clear = true })
			vim.api.nvim_create_autocmd("ColorScheme", {
				group = group,
				pattern = "vim",
				callback = clear_gutter_backgrounds,
			})
		end,
		opts = {
			colorscheme = "vim",
		},
	},
}
