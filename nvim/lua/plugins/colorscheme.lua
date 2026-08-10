local colors = {
	background = "#FFFFFF",
	foreground = "#171717",
	comment = "#5C6370",
	blue = "#0000D7",
	purple = "#7A00CC",
	cyan = "#007A7A",
	green = "#008000",
	orange = "#B84000",
	magenta = "#B0008F",
	red = "#D00000",
}

local function apply_vim_paper()
	local highlights = {
		Normal = { fg = colors.foreground, bg = colors.background },
		NormalNC = { fg = colors.foreground, bg = colors.background },
		NormalFloat = { fg = colors.foreground, bg = "#F7F7F7" },
		FloatBorder = { fg = "#808080", bg = "#F7F7F7" },
		SignColumn = { bg = colors.background },
		FoldColumn = { fg = "#888888", bg = colors.background },
		LineNr = { fg = "#A0A0A0", bg = colors.background },
		CursorLine = { bg = "#F0F3F8" },
		CursorLineNr = { fg = colors.blue, bg = "#F0F3F8", bold = true },
		CursorLineSign = { bg = "#F0F3F8" },
		CursorLineFold = { bg = "#F0F3F8" },
		Visual = { bg = "#BFDFFF" },
		Search = { fg = "#000000", bg = "#FFD700" },
		IncSearch = { fg = "#FFFFFF", bg = "#D05000" },
		Pmenu = { fg = colors.foreground, bg = "#F2F2F2" },
		PmenuSel = { fg = "#FFFFFF", bg = colors.blue, bold = true },
		Comment = { fg = colors.comment },
		Constant = { fg = colors.orange },
		String = { fg = colors.green },
		Character = { fg = colors.green },
		Number = { fg = colors.orange },
		Boolean = { fg = colors.orange, bold = true },
		Identifier = { fg = colors.foreground },
		Function = { fg = colors.cyan, bold = true },
		Statement = { fg = colors.blue, bold = true },
		PreProc = { fg = colors.magenta },
		Type = { fg = colors.purple, bold = true },
		Special = { fg = colors.orange },
		Operator = { fg = colors.red },
		Error = { fg = "#FFFFFF", bg = colors.red, bold = true },
		Todo = { fg = "#000000", bg = "#FFFF00", bold = true },
		["@comment"] = { fg = colors.comment },
		["@keyword"] = { fg = colors.blue, bold = true },
		["@keyword.conditional"] = { fg = colors.blue, bold = true },
		["@keyword.repeat"] = { fg = colors.blue, bold = true },
		["@keyword.exception"] = { fg = colors.blue, bold = true },
		["@type"] = { fg = colors.purple, bold = true },
		["@type.builtin"] = { fg = colors.purple, bold = true },
		["@constructor"] = { fg = colors.purple, bold = true },
		["@function"] = { fg = colors.cyan, bold = true },
		["@function.method"] = { fg = colors.cyan, bold = true },
		["@string"] = { fg = colors.green },
		["@number"] = { fg = colors.orange },
		["@number.float"] = { fg = colors.orange },
		["@boolean"] = { fg = colors.orange, bold = true },
		["@constant"] = { fg = colors.orange },
		["@property"] = { fg = colors.magenta },
		["@variable.member"] = { fg = colors.magenta },
		["@operator"] = { fg = colors.red },
	}

	for group, highlight in pairs(highlights) do
		vim.api.nvim_set_hl(0, group, highlight)
	end
end

return {
	{
		"LazyVim/LazyVim",
		init = function()
			local group = vim.api.nvim_create_augroup("cp_template_vim_paper", { clear = true })
			vim.api.nvim_create_autocmd("ColorScheme", {
				group = group,
				pattern = "vim",
				callback = apply_vim_paper,
			})
		end,
		opts = {
			colorscheme = "vim",
		},
	},
}
