local bootstrap = dofile("tests/bootstrap.lua")

vim.g.neovide = true
bootstrap.load_config()

vim.cmd("enew")
vim.cmd("file already-open.cpp")
vim.cmd("setfiletype cpp")
local preloaded_cpp_buf = vim.api.nvim_get_current_buf()

local preloaded_java_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(preloaded_java_buf, "already-open.java")
vim.api.nvim_set_option_value("filetype", "java", { buf = preloaded_java_buf })
local preloaded_python_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(preloaded_python_buf, "already-open.py")
vim.api.nvim_set_option_value("filetype", "python", { buf = preloaded_python_buf })

bootstrap.load_autocmds()

local cpp_tasks = require("config.cpp_tasks")
local language_run = require("config.language_run")
local windows_runtime = require("config.windows_runtime")
local colorscheme_plugin_spec = dofile(vim.fs.joinpath(bootstrap.nvim_root, "lua", "plugins", "colorscheme.lua"))
local completion_plugin_spec = dofile(vim.fs.joinpath(bootstrap.nvim_root, "lua", "plugins", "completion.lua"))
local cpp_plugin_spec = dofile(vim.fs.joinpath(bootstrap.nvim_root, "lua", "plugins", "cpp.lua"))
local editor_plugin_spec = dofile(vim.fs.joinpath(bootstrap.nvim_root, "lua", "plugins", "editor.lua"))
local java_plugin_spec = dofile(vim.fs.joinpath(bootstrap.nvim_root, "lua", "plugins", "java.lua"))
local language_tools = require("config.language_tools")
local mason_plugin_spec = dofile(vim.fs.joinpath(bootstrap.nvim_root, "lua", "plugins", "mason.lua"))
local python_plugin_spec = dofile(vim.fs.joinpath(bootstrap.nvim_root, "lua", "plugins", "python.lua"))
local typst_plugin_spec = dofile(vim.fs.joinpath(bootstrap.nvim_root, "lua", "plugins", "typst.lua"))

local function fail(message)
	error(message, 0)
end

local function assert_true(value, message)
	if not value then
		fail(message)
	end
end

local function assert_equal(actual, expected, message)
	if not vim.deep_equal(actual, expected) then
		fail(string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
	end
end

local function map_exists(bufnr, mode, lhs)
	for _, map in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
		if map.lhs == lhs then
			return true
		end
	end
	return false
end

local function global_map_exists(mode, lhs)
	for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
		if map.lhs == lhs then
			return true
		end
	end
	return false
end

local function window_option(name)
	return vim.api.nvim_get_option_value(name, { win = 0 })
end

local function find_key(spec, lhs)
	for _, item in ipairs(spec) do
		if type(item) == "table" and type(item.keys) == "table" then
			for _, mapping in ipairs(item.keys) do
				if mapping[1] == lhs then
					return mapping
				end
			end
		end
	end
end

local function find_plugin(spec, name)
	for _, plugin in ipairs(spec) do
		if plugin[1] == name then
			return plugin
		end
	end
end

assert_true(not global_map_exists("n", "<F5>"), "<F5> should not be a global normal-mode map")
assert_true(not global_map_exists("n", "<F6>"), "<F6> should not be a global normal-mode map")
assert_equal(vim.g.neovide_cursor_animation_length, 0, "Neovide cursor animation should be disabled")
assert_equal(vim.g.neovide_position_animation_length, 0, "Neovide position animation should be disabled")
assert_equal(vim.g.neovide_cursor_trail_size, 0, "Neovide cursor trail should be disabled")
assert_equal(vim.g.neovide_cursor_animate_in_insert_mode, false, "Neovide insert cursor animation should be disabled")
assert_equal(vim.g.neovide_cursor_animate_command_line, false, "Neovide command cursor animation should be disabled")
assert_equal(vim.g.neovide_cursor_antialiasing, false, "Neovide cursor antialiasing should be disabled")
assert_equal(vim.g.neovide_scroll_animation_length, 0, "Neovide scroll animation should be disabled")
assert_equal(vim.g.neovide_cursor_vfx_mode, "", "Neovide cursor VFX should be disabled")
assert_equal(vim.g.neovide_padding_top, 6, "Neovide should have small top padding")
assert_equal(vim.g.neovide_padding_bottom, 0, "Neovide should not have bottom padding")
assert_equal(vim.g.neovide_padding_left, 4, "Neovide should have subtle left padding")
assert_equal(vim.g.neovide_padding_right, 4, "Neovide should have subtle right padding")
assert_equal(vim.o.guifont, "JetBrainsMonoNL NF:h11", "Neovide should use the no-ligature Nerd Font family")
assert_equal(vim.o.background, "light", "editor background mode should match classic light gVim")
assert_equal(vim.wo.list, false, "tabs and trailing spaces should not render as visible markers")
assert_equal(vim.wo.statuscolumn, "", "code windows should use Neovim's native fixed-width gutter")
assert_equal(vim.wo.signcolumn, "yes:1", "code windows should reserve exactly one sign column")
assert_equal(vim.wo.foldcolumn, "0", "code windows should not reserve a fold column")
assert_equal(vim.wo.numberwidth, 4, "code windows should use a stable four-cell number column")

local colorscheme = find_plugin(colorscheme_plugin_spec, "LazyVim/LazyVim")
assert_true(colorscheme ~= nil, "colorscheme spec should configure LazyVim")
assert_equal(colorscheme.opts.colorscheme, "vim", "the vivid paper palette should use the built-in Vim scheme")
assert_true(type(colorscheme.init) == "function", "the Vim paper palette should register its color override")
colorscheme.init()
vim.cmd.colorscheme("vim")
local function highlight_hex(group, key)
	return string.format("#%06X", vim.api.nvim_get_hl(0, { name = group, link = false })[key])
end
assert_equal(highlight_hex("Normal", "bg"), "#FFFFFF", "the editor background should be true white")
assert_equal(highlight_hex("@keyword", "fg"), "#0000D7", "keywords should use saturated blue")
assert_equal(highlight_hex("@type", "fg"), "#7A00CC", "types should use saturated purple")
assert_equal(highlight_hex("@function.method", "fg"), "#007A7A", "methods should use saturated cyan")
assert_equal(highlight_hex("@string", "fg"), "#008000", "strings should use saturated green")
assert_equal(highlight_hex("@number", "fg"), "#B84000", "numbers should use saturated orange")
assert_equal(highlight_hex("@variable.member", "fg"), "#B0008F", "members should use saturated magenta")
assert_equal(highlight_hex("@operator", "fg"), "#D00000", "operators should use saturated red")
local completion = find_plugin(completion_plugin_spec, "saghen/blink.cmp")
assert_true(completion ~= nil, "completion spec should configure blink.cmp")
assert_equal(completion.opts.keymap["<Tab>"], { "select_and_accept", "fallback" }, "Tab should accept completion and fallback to indent")

local lspconfig = find_plugin(cpp_plugin_spec, "neovim/nvim-lspconfig")
assert_true(lspconfig ~= nil, "C++ plugin spec should configure nvim-lspconfig")
assert_true(vim.tbl_contains(lspconfig.opts.inlay_hints.exclude, "c"), "C inlay hints should be disabled")
assert_true(vim.tbl_contains(lspconfig.opts.inlay_hints.exclude, "cpp"), "C++ inlay hints should be disabled")
local clangd = lspconfig.opts.servers.clangd
assert_equal(clangd.cmd[1], "clangd", "clangd command should use the system executable")
assert_equal(clangd.init_options.fallbackFlags[1], "-std=gnu++20", "clangd fallback should match C++ build mode")
local gxx_name = vim.fn.has("win32") == 1 and "g++.exe" or "g++"
local gxx = vim.fn.exepath(gxx_name):gsub("\\", "/")
if gxx ~= "" then
	assert_equal(clangd.cmd[2], "--query-driver=" .. gxx, "clangd should query the active g++ driver")
end
assert_equal(clangd.cmd[#clangd.cmd], "--fallback-style=none", "clangd should preserve standalone contest formatting")

local init_source = table.concat(vim.fn.readfile(vim.fs.joinpath(bootstrap.nvim_root, "init.lua")), "\n")
local lazyvim_core_position = assert(init_source:find('import = "lazyvim.plugins"', 1, true))
local java_extra_position = assert(init_source:find('import = "lazyvim.plugins.extras.lang.java"', 1, true))
local python_extra_position = assert(init_source:find('import = "lazyvim.plugins.extras.lang.python"', 1, true))
local local_plugins_position = assert(init_source:find('import = "plugins"', 1, true))
assert_true(lazyvim_core_position < java_extra_position, "LazyVim core must load before Java extra")
assert_true(java_extra_position < python_extra_position, "LazyVim extras should remain grouped together")
assert_true(python_extra_position < local_plugins_position, "LazyVim extras must load before local plugins")

local jdtls = find_plugin(java_plugin_spec, "mfussenegger/nvim-jdtls")
assert_true(jdtls ~= nil, "Java support should configure nvim-jdtls")
local java_lsp = find_plugin(java_plugin_spec, "neovim/nvim-lspconfig")
assert_equal(java_lsp.opts.servers.jdtls.mason, false, "JDTLS should use the pinned bootstrap installer")
local previous_temurin_home_for_jdtls = windows_runtime.temurin_home
windows_runtime.temurin_home = function(major)
	return ({
		[17] = "C:/Program Files/Eclipse Adoptium/jdk-17.0.99",
		[21] = "C:/Program Files/Eclipse Adoptium/jdk-21.0.99",
		[25] = "C:/Program Files/Eclipse Adoptium/jdk-25.0.99",
	})[major]
end
local jdtls_opts = {}
jdtls.opts(nil, jdtls_opts)
windows_runtime.temurin_home = previous_temurin_home_for_jdtls
assert_equal(jdtls_opts.dap, false, "Java debugging should stay disabled until explicitly needed")
assert_equal(jdtls_opts.test, false, "Java test adapters should stay disabled until explicitly needed")
assert_true(jdtls_opts.cmd[1]:match("mason[/\\]bin[/\\]jdtls") ~= nil, "JDTLS should use the pinned Mason command")
assert_equal(jdtls_opts.settings.java.configuration.runtimes[1].name, "JavaSE-17", "JDTLS should expose Java 17")
assert_equal(jdtls_opts.settings.java.configuration.runtimes[1].default, true, "Java 17 should remain the default source-file target")
assert_equal(jdtls_opts.settings.java.configuration.runtimes[2].name, "JavaSE-21", "JDTLS should expose Java 21")
assert_equal(jdtls_opts.settings.java.configuration.runtimes[3].name, "JavaSE-25", "JDTLS should expose Java 25 for Minecraft projects")
assert_equal(
	jdtls_opts.settings.java.inlayHints.parameterNames.enabled,
	"none",
	"Java parameter inlay hints should remain hidden"
)

local python_lsp = find_plugin(python_plugin_spec, "neovim/nvim-lspconfig")
assert_true(python_lsp ~= nil, "Python support should configure nvim-lspconfig")
assert_equal(
	python_lsp.opts.servers.basedpyright.mason,
	false,
	"BasedPyright should use the pinned bootstrap installer"
)
assert_equal(python_lsp.opts.servers.ruff.mason, false, "Ruff should use the pinned bootstrap installer")
assert_equal(
	python_lsp.opts.servers.basedpyright.settings.basedpyright.analysis.typeCheckingMode,
	"standard",
	"BasedPyright should use useful, non-strict type checking"
)
local python_conform = find_plugin(python_plugin_spec, "stevearc/conform.nvim")
assert_equal(python_conform.opts.formatters_by_ft.python[1], "ruff_format", "Ruff should format Python")

local mason = find_plugin(mason_plugin_spec, "mason-org/mason.nvim")
local mason_opts = {}
mason.opts(nil, mason_opts)
assert_equal(#mason_opts.ensure_installed, 0, "Mason's asynchronous unpinned installer should stay disabled")
local mason_lspconfig = find_plugin(mason_plugin_spec, "mason-org/mason-lspconfig.nvim")
local mason_lspconfig_opts = {}
mason_lspconfig.opts(nil, mason_lspconfig_opts)
assert_equal(#mason_lspconfig_opts.ensure_installed, 0, "mason-lspconfig's unpinned installer should stay disabled")
assert_equal(language_tools[1].name, "jdtls", "Pinned tools should include JDTLS")
assert_equal(language_tools[1].version, "v1.60.0", "JDTLS should have an exact version")
assert_equal(language_tools[2].name, "basedpyright", "Pinned tools should include BasedPyright")
assert_equal(language_tools[2].version, "1.39.9", "BasedPyright should have an exact version")
assert_equal(language_tools[3].name, "ruff", "Pinned tools should include Ruff")
assert_equal(language_tools[3].version, "0.15.22", "Ruff should have an exact version")

local lock_path = vim.fs.joinpath(bootstrap.nvim_root, "lazy-lock.json")
local lock = vim.json.decode(table.concat(vim.fn.readfile(lock_path), "\n"))
assert_true(lock["github-theme"] == nil, "unused GitHub theme should not remain locked")

local snacks = find_plugin(editor_plugin_spec, "folke/snacks.nvim")
assert_true(snacks ~= nil, "editor plugin spec should override snacks.nvim")
assert_equal(snacks.opts.scroll.enabled, false, "Snacks smooth scrolling should be disabled")
assert_equal(snacks.opts.indent.enabled, false, "Snacks indentation guides should be disabled")
local pairs = find_plugin(editor_plugin_spec, "nvim-mini/mini.pairs")
assert_equal(pairs.opts.modes.command, false, "auto-pairs should not alter command-line input")

local preview_toggle = find_key(typst_plugin_spec, "<leader>tp")
assert_true(preview_toggle ~= nil, "typst plugin spec should define <leader>tp")
assert_equal(
	preview_toggle[2],
	"<cmd>TypstPreviewToggle<CR>",
	"typst preview should use the authoritative toggle command"
)

assert_true(map_exists(preloaded_cpp_buf, "n", "<F5>"), "already-open cpp buffers should receive <F5>")
assert_true(map_exists(preloaded_cpp_buf, "n", "<F6>"), "already-open cpp buffers should receive <F6>")
assert_true(map_exists(preloaded_cpp_buf, "n", " it"), "already-open cpp buffers should receive <leader>it")
assert_true(map_exists(preloaded_java_buf, "n", "<F5>"), "already-open Java buffers should receive <F5>")
assert_true(map_exists(preloaded_java_buf, "n", " it"), "already-open Java buffers should receive <leader>it")
assert_equal(vim.api.nvim_get_option_value("shiftwidth", { buf = preloaded_java_buf }), 4, "Java should keep four spaces")
assert_true(map_exists(preloaded_python_buf, "n", "<F5>"), "already-open Python buffers should receive <F5>")
assert_true(map_exists(preloaded_python_buf, "n", " it"), "already-open Python buffers should receive <leader>it")
assert_true(vim.api.nvim_get_option_value("cindent", { buf = preloaded_cpp_buf }), "cpp should enable cindent locally")
assert_equal(vim.b[preloaded_cpp_buf].autoformat, false, "cpp should preserve contest formatting on save")
assert_equal(
	vim.api.nvim_get_option_value("cinoptions", { buf = preloaded_cpp_buf }),
	"{0,1s,t0,n-2,p2s,(03s,=.5s,>1s,=1s,:1s",
	"cpp should set cinoptions locally"
)

vim.cmd("enew")
vim.cmd("file test.cpp")
vim.cmd("setfiletype cpp")
local cpp_buf = vim.api.nvim_get_current_buf()

assert_true(map_exists(cpp_buf, "n", "<F5>"), "<F5> should exist in cpp normal mode")
assert_true(map_exists(cpp_buf, "i", "<F5>"), "<F5> should exist in cpp insert mode")
assert_true(map_exists(cpp_buf, "v", "<F5>"), "<F5> should exist in cpp visual mode")
assert_true(map_exists(cpp_buf, "n", "<F6>"), "<F6> should exist in cpp normal mode")
assert_true(map_exists(cpp_buf, "i", "<F6>"), "<F6> should exist in cpp insert mode")
assert_true(map_exists(cpp_buf, "v", "<F6>"), "<F6> should exist in cpp visual mode")
assert_true(map_exists(cpp_buf, "n", " it"), "<leader>it should exist in cpp normal mode")
assert_true(map_exists(cpp_buf, "n", " rx"), "<leader>rx should close the C++ run panel")
assert_true(vim.api.nvim_buf_get_commands(cpp_buf, {}).TemplateCpp ~= nil, "TemplateCpp should exist in C++ buffers")
assert_true(vim.api.nvim_buf_get_commands(cpp_buf, {}).CppTemplate ~= nil, "CppTemplate should remain available in C++ buffers")
assert_true(vim.api.nvim_buf_get_commands(cpp_buf, {}).TemplateCPP ~= nil, "historical TemplateCPP should remain available")
assert_true(vim.api.nvim_buf_get_commands(cpp_buf, {}).CppClose ~= nil, "CppClose should exist in C++ buffers")
assert_equal(vim.b[cpp_buf].autoformat, false, "new cpp buffers should disable format-on-save")

vim.cmd("enew")
vim.cmd("file PracticeSession.java")
vim.cmd("setfiletype java")
local java_buf = vim.api.nvim_get_current_buf()
assert_true(map_exists(java_buf, "n", "<F5>"), "<F5> should exist in Java normal mode")
assert_true(map_exists(java_buf, "i", "<F5>"), "<F5> should exist in Java insert mode")
assert_true(map_exists(java_buf, "v", "<F5>"), "<F5> should exist in Java visual mode")
assert_true(map_exists(java_buf, "n", " it"), "<leader>it should exist in Java normal mode")
assert_true(vim.api.nvim_buf_get_commands(java_buf, {}).LanguageRun ~= nil, "LanguageRun should exist in Java buffers")
assert_true(vim.api.nvim_buf_get_commands(java_buf, {}).TemplateJava ~= nil, "TemplateJava should exist in Java buffers")

local original_get_client = vim.lsp.get_client_by_id
local fake_jdtls = { id = 42, name = "jdtls", server_capabilities = { semanticTokensProvider = {} } }
vim.lsp.get_client_by_id = function()
	return fake_jdtls
end
vim.api.nvim_exec_autocmds("LspAttach", { buffer = java_buf, data = { client_id = fake_jdtls.id } })
vim.lsp.get_client_by_id = original_get_client
assert_true(fake_jdtls.server_capabilities.semanticTokensProvider == nil, "JDTLS semantic tokens should stay disabled")

vim.cmd("enew")
vim.cmd("file practice.py")
vim.cmd("setfiletype python")
local python_buf = vim.api.nvim_get_current_buf()
assert_true(map_exists(python_buf, "n", "<F5>"), "<F5> should exist in Python normal mode")
assert_true(map_exists(python_buf, "i", "<F5>"), "<F5> should exist in Python insert mode")
assert_true(map_exists(python_buf, "v", "<F5>"), "<F5> should exist in Python visual mode")
assert_true(map_exists(python_buf, "n", " it"), "<leader>it should exist in Python normal mode")
assert_true(
	vim.api.nvim_buf_get_commands(python_buf, {}).LanguageRun ~= nil,
	"LanguageRun should exist in Python buffers"
)
assert_true(vim.api.nvim_buf_get_commands(python_buf, {}).TemplatePython ~= nil, "TemplatePython should exist in Python buffers")

local cpp_template_file = vim.fn.readfile(vim.fs.joinpath(bootstrap.repo_root, "templates", "cpp.cpp"))
vim.api.nvim_set_current_buf(cpp_buf)
vim.cmd("CppTemplate")
local template_cursor = vim.api.nvim_win_get_cursor(0)
assert_equal(template_cursor[1], 35, "C++ template cursor should land on the solve body line")
assert_equal(template_cursor[2], 4, "C++ template insert cursor should follow all four indentation spaces")
vim.cmd("stopinsert")
local template_lines = vim.api.nvim_buf_get_lines(cpp_buf, 0, -1, false)
assert_equal(template_lines, cpp_template_file, "C++ insertion should match the canonical shared template")

local template_snapshot = table.concat(template_lines, "\n")
vim.cmd("TemplateCpp")
assert_equal(
	table.concat(vim.api.nvim_buf_get_lines(cpp_buf, 0, -1, false), "\n"),
	template_snapshot,
	"C++ template should not overwrite a nonblank buffer"
)
vim.bo[cpp_buf].modified = false

vim.api.nvim_set_current_buf(java_buf)
vim.cmd("TemplateJava")
local java_cursor = vim.api.nvim_win_get_cursor(0)
local java_lines = vim.api.nvim_buf_get_lines(java_buf, 0, -1, false)
assert_equal(java_lines[5], "public class PracticeSession {", "Java template should substitute the filename stem")
assert_true(not table.concat(java_lines, "\n"):find("{{CLASS_NAME}}", 1, true), "Java template should replace every class placeholder")
assert_equal(java_lines[java_cursor[1]], "        ", "Java cursor should land on the blank solve body line")
assert_equal(java_cursor[2], #java_lines[java_cursor[1]], "Java cursor should land at the end of the solve body line")
vim.cmd("stopinsert")
local java_snapshot = table.concat(java_lines, "\n")
vim.cmd("TemplateJava")
assert_equal(
	table.concat(vim.api.nvim_buf_get_lines(java_buf, 0, -1, false), "\n"),
	java_snapshot,
	"Java template should not overwrite a nonblank buffer"
)
vim.bo[java_buf].modified = false

vim.cmd("enew")
vim.cmd("file exports.java")
vim.cmd("setfiletype java")
local reserved_java_buf = vim.api.nvim_get_current_buf()
pcall(vim.cmd, "TemplateJava")
assert_equal(
	vim.api.nvim_buf_get_lines(reserved_java_buf, 0, -1, false),
	{ "" },
	"Java template should reject reserved public class names"
)
vim.bo[reserved_java_buf].modified = false

vim.api.nvim_set_current_buf(python_buf)
vim.cmd("TemplatePython")
local python_cursor = vim.api.nvim_win_get_cursor(0)
local python_lines = vim.api.nvim_buf_get_lines(python_buf, 0, -1, false)
assert_equal(python_lines[4], "def solve() -> None:", "Python template should define solve()")
assert_equal(python_lines[6], "    pass", "Python template should remain runnable before solve is implemented")
assert_equal(python_lines[python_cursor[1]], "    ", "Python cursor should land on the blank solve body line")
assert_equal(python_cursor[2], #python_lines[python_cursor[1]], "Python cursor should land at the end of the solve body line")
vim.cmd("stopinsert")
local python_snapshot = table.concat(python_lines, "\n")
vim.cmd("TemplatePython")
assert_equal(
	table.concat(vim.api.nvim_buf_get_lines(python_buf, 0, -1, false), "\n"),
	python_snapshot,
	"Python template should not overwrite a nonblank buffer"
)
vim.bo[python_buf].modified = false

vim.cmd("enew")
vim.cmd("file notes.md")
vim.cmd("setfiletype markdown")
local markdown_buf = vim.api.nvim_get_current_buf()

assert_true(not map_exists(markdown_buf, "n", "<F5>"), "<F5> must be absent in markdown")
assert_true(not map_exists(markdown_buf, "n", "<F6>"), "<F6> must be absent in markdown")
assert_true(not map_exists(markdown_buf, "n", " it"), "C++ template map must be absent in markdown")
assert_true(vim.api.nvim_buf_get_commands(markdown_buf, {}).TemplateCpp == nil, "TemplateCpp must be absent in markdown")
assert_true(vim.api.nvim_buf_get_commands(markdown_buf, {}).TemplateJava == nil, "TemplateJava must be absent in markdown")
assert_true(vim.api.nvim_buf_get_commands(markdown_buf, {}).TemplatePython == nil, "TemplatePython must be absent in markdown")
assert_true(window_option("wrap"), "markdown should enable wrap")
assert_true(window_option("linebreak"), "markdown should enable linebreak")
assert_true(window_option("breakindent"), "markdown should enable breakindent")
assert_true(window_option("spell"), "markdown should enable spell")
assert_equal(vim.api.nvim_get_option_value("spelllang", { buf = 0 }), "en_us", "markdown should set spelllang")
assert_equal(
	vim.api.nvim_get_option_value("cindent", { buf = markdown_buf }),
	false,
	"markdown must not inherit cindent"
)
assert_equal(
	vim.api.nvim_get_option_value("cinoptions", { buf = markdown_buf }),
	"",
	"markdown must not inherit cinoptions"
)

vim.cmd("enew")
vim.cmd("file paper.typ")
vim.cmd("setfiletype typst")
local typst_buf = vim.api.nvim_get_current_buf()

assert_true(not map_exists(typst_buf, "n", "<F5>"), "<F5> must be absent in typst")
assert_true(not map_exists(typst_buf, "n", "<F6>"), "<F6> must be absent in typst")
assert_true(window_option("wrap"), "typst should enable wrap")
assert_true(window_option("spell"), "typst should enable spell")
assert_equal(vim.api.nvim_get_option_value("cindent", { buf = typst_buf }), false, "typst must not inherit cindent")
assert_equal(vim.api.nvim_get_option_value("cinoptions", { buf = typst_buf }), "", "typst must not inherit cinoptions")

vim.cmd("enew")
vim.cmd("file hello.c")
vim.cmd("setfiletype c")
local c_buf = vim.api.nvim_get_current_buf()

assert_true(vim.api.nvim_get_option_value("cindent", { buf = c_buf }), "c should enable cindent locally")
assert_equal(
	vim.api.nvim_get_option_value("cinoptions", { buf = c_buf }),
	"{0,1s,t0,n-2,p2s,(03s,=.5s,>1s,=1s,:1s",
	"c should set cinoptions locally"
)

vim.cmd("enew")
vim.cmd("file main.cpp")
vim.cmd("setfiletype cpp")
local cpp_after_prose = vim.api.nvim_get_current_buf()

assert_equal(window_option("wrap"), false, "cpp wrap should stay at the global baseline")
assert_equal(window_option("linebreak"), false, "cpp linebreak should stay at the global baseline")
assert_equal(window_option("breakindent"), false, "cpp breakindent should stay at the global baseline")
assert_equal(window_option("spell"), false, "cpp spell should stay at the global baseline")
assert_true(
	vim.api.nvim_get_option_value("cindent", { buf = cpp_after_prose }),
	"cpp should still get cindent after prose buffers"
)

local source_with_spaces = vim.fs.joinpath(vim.fn.stdpath("cache"), "test dir", "main file.cpp")
local argv = cpp_tasks.build_argv(source_with_spaces)
local expected_output_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "cpp-build")

assert_equal(argv[1], "g++", "argv should start with g++")
assert_equal(argv[6], source_with_spaces, "source path with spaces must stay a single argv entry")
assert_equal(argv[7], "-o", "argv should include -o before the output path")
assert_true(vim.startswith(argv[8], expected_output_dir), "output path should live under stdpath('cache')/cpp-build")
assert_true(argv[8]:match("%.exe$") ~= nil, "output path should end in .exe")

local runner_root = vim.fs.joinpath(vim.fn.stdpath("cache"), "language runner test")
local fake_python = vim.fs.joinpath(runner_root, "selected venv", "python.exe")
vim.fn.mkdir(vim.fs.dirname(fake_python), "p")
vim.fn.writefile({ "#!/bin/sh", "exit 0" }, fake_python)
pcall(vim.uv.fs_chmod, fake_python, 493)
local previous_selector = package.loaded["venv-selector"]
package.loaded["venv-selector"] = {
	python = function()
		return vim.fn.fnamemodify(fake_python, ":.")
	end,
}
local python_source = vim.fs.joinpath(runner_root, "source dir", "main file.py")
vim.api.nvim_buf_set_name(python_buf, python_source)
local python_argv = assert(language_run.command_for(python_buf))
assert_equal(python_argv[1], fake_python, "Python runs should honor the selected virtual environment")
assert_equal(python_argv[2], python_source, "Python source paths with spaces should stay one argv entry")

local local_python = vim.fs.joinpath(vim.fs.dirname(python_source), "python.exe")
vim.fn.mkdir(vim.fs.dirname(local_python), "p")
vim.fn.writefile({ "#!/bin/sh", "exit 0" }, local_python)
pcall(vim.uv.fs_chmod, local_python, 493)
package.loaded["venv-selector"] = {
	python = function()
		return nil
	end,
}
local fallback_python_argv = assert(language_run.command_for(python_buf))
assert_true(fallback_python_argv[1] ~= local_python, "Python PATH fallback must not select a project-local executable")
assert_true(
	fallback_python_argv[1]:match("^/") ~= nil or fallback_python_argv[1]:match("^%a:[/\\]") ~= nil,
	"Python PATH fallback should resolve to an absolute path"
)
package.loaded["venv-selector"] = previous_selector

local previous_temurin_home = windows_runtime.temurin_home
local fake_jdk = vim.fs.joinpath(runner_root, "jdk 17")
local fake_java = vim.fs.joinpath(fake_jdk, "bin", "java.exe")
vim.fn.mkdir(vim.fs.dirname(fake_java), "p")
vim.fn.writefile({ "#!/bin/sh", "exit 0" }, fake_java)
pcall(vim.uv.fs_chmod, fake_java, 493)
windows_runtime.temurin_home = function()
	return fake_jdk
end
local java_source = vim.fs.joinpath(runner_root, "source dir", "Main File.java")
vim.api.nvim_buf_set_name(java_buf, java_source)
local java_argv = assert(language_run.command_for(java_buf))
assert_equal(java_argv[1], fake_java, "Java runs should use the configured Java 17 runtime")
assert_equal(java_argv[2], "--source", "Java runs should use source-file mode")
assert_equal(java_argv[3], "17", "Java source-file mode should target Java 17")
assert_equal(java_argv[4], java_source, "Java source paths with spaces should stay one argv entry")
windows_runtime.temurin_home = previous_temurin_home

local local_java = vim.fs.joinpath(vim.fs.dirname(java_source), "java.exe")
vim.fn.mkdir(vim.fs.dirname(local_java), "p")
vim.fn.writefile({ "#!/bin/sh", "exit 0" }, local_java)
pcall(vim.uv.fs_chmod, local_java, 493)
local fallback_java_argv = language_run.command_for(java_buf)
if fallback_java_argv then
	assert_true(fallback_java_argv[1] ~= local_java, "Java PATH fallback must not select a project-local executable")
	assert_true(
		fallback_java_argv[1]:match("^/") ~= nil or fallback_java_argv[1]:match("^%a:[/\\]") ~= nil,
		"Java PATH fallback should resolve to an absolute path"
	)
end
vim.fn.delete(runner_root, "rf")

local autosave_path = vim.fn.tempname() .. ".txt"
vim.fn.writefile({ "before" }, autosave_path)
vim.cmd.edit(vim.fn.fnameescape(autosave_path))
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "after" })
vim.api.nvim_exec_autocmds("CursorHoldI", { buffer = 0 })
assert_equal(vim.fn.readfile(autosave_path)[1], "after", "autosave should persist edits on idle")
vim.cmd.bwipeout({ bang = true })
vim.fn.delete(autosave_path)

print("tests/run.lua: ok")
