-- Java projects target Java 17. Current JDTLS itself requires Java 21, so the
-- installer provides both runtimes and this spec keeps their roles explicit.

local windows_runtime = require("config.windows_runtime")

return {
	{ import = "lazyvim.plugins.extras.lang.java" },
	{
		"neovim/nvim-lspconfig",
		opts = { servers = { jdtls = { mason = false } } },
	},
	{
		"mfussenegger/nvim-jdtls",
		opts = function(_, opts)
			local jdk17 = windows_runtime.temurin_home(17)
			local jdk21 = windows_runtime.temurin_home(21)
			local python_home = windows_runtime.python_home()
			local mason_root = vim.fs.joinpath(vim.fn.stdpath("data"), "mason")
			local jdtls = vim.fs.joinpath(mason_root, "bin", vim.fn.has("win32") == 1 and "jdtls.cmd" or "jdtls")

			opts.dap = false
			opts.dap_main = false
			opts.test = false
			opts.cmd = {
				jdtls,
				"--jvm-arg=-javaagent:" .. vim.fs.joinpath(mason_root, "share", "jdtls", "lombok.jar"),
			}
			opts.settings = vim.tbl_deep_extend("force", opts.settings or {}, {
				java = {
					configuration = {
						runtimes = jdk17 and {
							{ name = "JavaSE-17", path = jdk17, default = true },
						} or nil,
					},
					inlayHints = { parameterNames = { enabled = "none" } },
				},
			})

			opts.jdtls = function(config)
				if jdk21 or python_home then
					config.cmd_env = {
						JAVA_HOME = jdk21 or vim.env.JAVA_HOME,
						PATH = windows_runtime.with_path({
							jdk21 and vim.fs.joinpath(jdk21, "bin") or nil,
							python_home,
						}),
					}
				end
				return config
			end
		end,
	},
}
