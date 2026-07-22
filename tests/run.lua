local bootstrap = dofile("tests/bootstrap.lua")

vim.g.neovide = true
bootstrap.load_config()

vim.cmd("enew")
vim.cmd("file already-open.cpp")
vim.cmd("setfiletype cpp")
local preloaded_cpp_buf = vim.api.nvim_get_current_buf()

bootstrap.load_autocmds()

local cpp_tasks = require("config.cpp_tasks")
local colorscheme_plugin_spec = dofile(vim.fs.joinpath(bootstrap.nvim_root, "lua", "plugins", "colorscheme.lua"))
local cpp_plugin_spec = dofile(vim.fs.joinpath(bootstrap.nvim_root, "lua", "plugins", "cpp.lua"))
local editor_plugin_spec = dofile(vim.fs.joinpath(bootstrap.nvim_root, "lua", "plugins", "editor.lua"))
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
	if actual ~= expected then
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
assert_equal(colorscheme.opts.colorscheme, "vim", "classic built-in Vim colors should be active")

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

local lock_path = vim.fs.joinpath(bootstrap.nvim_root, "lazy-lock.json")
local lock = vim.json.decode(table.concat(vim.fn.readfile(lock_path), "\n"))
assert_true(lock["github-theme"] == nil, "unused GitHub theme should not remain locked")

local snacks = find_plugin(editor_plugin_spec, "folke/snacks.nvim")
assert_true(snacks ~= nil, "editor plugin spec should override snacks.nvim")
assert_equal(snacks.opts.scroll.enabled, false, "Snacks smooth scrolling should be disabled")
assert_equal(snacks.opts.indent.enabled, false, "Snacks indentation guides should be disabled")

local preview_toggle = find_key(typst_plugin_spec, "<leader>tp")
assert_true(preview_toggle ~= nil, "typst plugin spec should define <leader>tp")
assert_equal(
	preview_toggle[2],
	"<cmd>TypstPreviewToggle<CR>",
	"typst preview should use the authoritative toggle command"
)

assert_true(map_exists(preloaded_cpp_buf, "n", "<F5>"), "already-open cpp buffers should receive <F5>")
assert_true(map_exists(preloaded_cpp_buf, "n", "<F6>"), "already-open cpp buffers should receive <F6>")
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
assert_true(vim.api.nvim_buf_get_commands(cpp_buf, {}).CppClose ~= nil, "CppClose should exist in C++ buffers")
assert_equal(vim.b[cpp_buf].autoformat, false, "new cpp buffers should disable format-on-save")

vim.cmd("CppTemplate")
local template_cursor = vim.api.nvim_win_get_cursor(0)
assert_equal(template_cursor[1], 35, "C++ template cursor should land on the solve body line")
assert_equal(template_cursor[2], 4, "C++ template insert cursor should follow all four indentation spaces")
vim.cmd("stopinsert")
local template_lines = vim.api.nvim_buf_get_lines(cpp_buf, 0, -1, false)
assert_equal(
	template_lines[1],
	'#pragma GCC optimize("O3,unroll-loops")',
	"C++ template should enable GCC optimizations"
)
assert_equal(
	template_lines[2],
	'#pragma GCC target("avx2,bmi,bmi2,lzcnt,popcnt")',
	"C++ template should set CPU targets"
)
assert_equal(template_lines[3], "#include <bits/stdc++.h>", "C++ template should include the contest header")
assert_equal(
	template_lines[17],
	"#define FASTIO ios_base::sync_with_stdio(false);cin.tie(NULL);",
	"C++ template should define fast I/O"
)
assert_equal(
	template_lines[25],
	"template<typename T> bool chmin(T& a, const T& b) {",
	"C++ template should define chmin"
)
assert_equal(template_lines[34], "void solve() {", "C++ template should define solve")
assert_equal(template_lines[41], "    cin >> t;", "C++ template should read the test count")
assert_equal(template_lines[43], "        solve();", "C++ template should call solve")

local template_snapshot = table.concat(template_lines, "\n")
vim.cmd("CppTemplate")
assert_equal(
	table.concat(vim.api.nvim_buf_get_lines(cpp_buf, 0, -1, false), "\n"),
	template_snapshot,
	"C++ template should not overwrite a nonblank buffer"
)
vim.bo[cpp_buf].modified = false

vim.cmd("enew")
vim.cmd("file notes.md")
vim.cmd("setfiletype markdown")
local markdown_buf = vim.api.nvim_get_current_buf()

assert_true(not map_exists(markdown_buf, "n", "<F5>"), "<F5> must be absent in markdown")
assert_true(not map_exists(markdown_buf, "n", "<F6>"), "<F6> must be absent in markdown")
assert_true(not map_exists(markdown_buf, "n", " it"), "C++ template map must be absent in markdown")
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

print("tests/run.lua: ok")
