-- ============================================================================
-- autocmds.lua -- filetype-local ergonomics
-- ============================================================================

local prose_group = vim.api.nvim_create_augroup("cp_template_prose", { clear = true })
local indent_group = vim.api.nvim_create_augroup("cp_template_c_indent", { clear = true })

require("config.cpp_tasks").setup()
require("config.language_run").setup()
require("config.language_templates").setup()
require("config.notes").setup()

local function apply_prose_settings()
	vim.opt_local.wrap = true
	vim.opt_local.linebreak = true
	vim.opt_local.breakindent = true
	vim.opt_local.spell = true
	vim.opt_local.spelllang = { "en_us" }
end

local function apply_c_indent()
	vim.opt_local.cindent = true
	vim.opt_local.cinoptions = "{0,1s,t0,n-2,p2s,(03s,=.5s,>1s,=1s,:1s"
	-- Preserve compact contest macros and helpers instead of letting clangd's
	-- default style rewrite them whenever the file is saved.
	vim.b.autoformat = false
end

vim.api.nvim_create_autocmd("FileType", {
	group = prose_group,
	pattern = { "markdown", "typst" },
	callback = apply_prose_settings,
})

vim.api.nvim_create_autocmd("FileType", {
	group = indent_group,
	pattern = { "c", "cpp" },
	callback = apply_c_indent,
})

for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
	if vim.api.nvim_buf_is_loaded(bufnr) then
		local filetype = vim.bo[bufnr].filetype
		if filetype == "markdown" or filetype == "typst" then
			vim.api.nvim_buf_call(bufnr, apply_prose_settings)
		elseif filetype == "c" or filetype == "cpp" then
			vim.api.nvim_buf_call(bufnr, apply_c_indent)
		end
	end
end
