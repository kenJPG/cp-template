-- Java projects target Java 17. JDTLS runs on Java 21, while Minecraft 26.x
-- projects can select the installed Java 25 runtime.

local windows_runtime = require("config.windows_runtime")

return {
	{
		"neovim/nvim-lspconfig",
		opts = { servers = { jdtls = { mason = false } } },
	},
	{
		"mfussenegger/nvim-jdtls",
		opts = function(_, opts)
			local jdk17 = windows_runtime.temurin_home(17)
			local jdk21 = windows_runtime.temurin_home(21)
			local jdk25 = windows_runtime.temurin_home(25)
			local python_home = windows_runtime.python_home()
			local mason_root = vim.fs.joinpath(vim.fn.stdpath("data"), "mason")
			local jdtls = vim.fs.joinpath(mason_root, "bin", vim.fn.has("win32") == 1 and "jdtls.cmd" or "jdtls")
			local runtimes = {}
			if jdk17 then
				runtimes[#runtimes + 1] = { name = "JavaSE-17", path = jdk17, default = true }
			end
			if jdk21 then
				runtimes[#runtimes + 1] = { name = "JavaSE-21", path = jdk21 }
			end
			if jdk25 then
				runtimes[#runtimes + 1] = { name = "JavaSE-25", path = jdk25 }
			end

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
						runtimes = #runtimes > 0 and runtimes or nil,
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
