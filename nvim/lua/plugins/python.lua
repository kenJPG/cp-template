-- BasedPyright provides type-aware completion/navigation; Ruff is the single
-- fast linter and formatter. The LazyVim extra also supplies .venv selection.
vim.g.lazyvim_python_lsp = "basedpyright"
vim.g.lazyvim_python_ruff = "ruff"

local windows_runtime = require("config.windows_runtime")
local python_home = windows_runtime.python_home()

return {
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				basedpyright = {
					mason = false,
					cmd_env = python_home and { PATH = windows_runtime.with_path({ python_home }) } or nil,
					settings = {
						basedpyright = {
							analysis = { typeCheckingMode = "standard" },
						},
					},
				},
				ruff = { mason = false },
			},
		},
	},
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				python = { "ruff_format" },
			},
		},
	},
}
