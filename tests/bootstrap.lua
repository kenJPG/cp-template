local M = {}

local script_path = debug.getinfo(1, "S").source:sub(2)

M.repo_root = vim.fn.fnamemodify(script_path, ":p:h:h")
M.nvim_root = vim.fs.joinpath(M.repo_root, "nvim")

function M.load_config()
	vim.opt.runtimepath:prepend(M.nvim_root)
	vim.g.mapleader = " "
	vim.g.maplocalleader = "\\"

	vim.opt.wrap = false
	vim.opt.linebreak = false
	vim.opt.breakindent = false
	vim.opt.spell = false
	vim.opt.swapfile = false
	vim.opt.cindent = false
	vim.opt.cinoptions = ""

	dofile(vim.fs.joinpath(M.nvim_root, "lua", "config", "options.lua"))
	dofile(vim.fs.joinpath(M.nvim_root, "lua", "config", "keymaps.lua"))
end

function M.load_autocmds()
	dofile(vim.fs.joinpath(M.nvim_root, "lua", "config", "autocmds.lua"))
end

return M
