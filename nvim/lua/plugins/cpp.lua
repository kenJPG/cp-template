-- ============================================================================
-- cpp.lua — C++ language support (competitive programming)
-- ============================================================================
-- clangd provides completion and diagnostics while g++ remains the real
-- compiler. Allow clangd to query the exact g++ resolved on PATH so MinGW's
-- libstdc++ headers (including bits/stdc++.h) are visible to the editor.
--
-- bootstrap.ps1 writes the same driver to clangd's global config as Compiler,
-- which makes this narrow query-driver allowlist effective for standalone files.
-- ============================================================================

local clangd_cmd = { "clangd" }
local gxx_name = vim.fn.has("win32") == 1 and "g++.exe" or "g++"
local gxx = vim.fn.exepath(gxx_name)
if gxx ~= "" then
	clangd_cmd[#clangd_cmd + 1] = "--query-driver=" .. gxx:gsub("\\", "/")
end
clangd_cmd[#clangd_cmd + 1] = "--fallback-style=none"

return {
	{
		"neovim/nvim-lspconfig",
		opts = {
			inlay_hints = {
				exclude = { "vue", "c", "cpp", "objc", "objcpp", "cuda" },
			},
			servers = {
				clangd = {
					mason = false,
					cmd = clangd_cmd,
					init_options = {
						fallbackFlags = { "-std=gnu++20" },
					},
				},
			},
		},
	},
}
