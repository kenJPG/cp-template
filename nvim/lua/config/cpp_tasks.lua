-- ============================================================================
-- cpp_tasks.lua -- buffer-local C++ build/run workflow
-- ============================================================================
-- Keeps the competitive-programming task flow out of keymaps.lua:
--   * async compile with vim.system(argv)
--   * diagnostics parsed into quickfix on failure
--   * one reusable panel: scratch buffer for stdin, live terminal for the run
--     (stdin stays open after the pre-fed input, so interactive problems work)
-- ============================================================================

local M = {}

local augroup = vim.api.nvim_create_augroup("cp_template_cpp_tasks", { clear = true })

local state = {
	setup_done = false,
	panel_position = (vim.g.cpp_panel_position == "right") and "right" or "bottom",
	panel_bufnr = nil,
	panel_winid = nil,
	panel_kind = nil,
	editor_bufnr = nil,
	editor_winid = nil,
	source_path = nil,
	output_path = nil,
	input_lines = { "" },
	build_generation = 0,
	build_system = nil,
	run_generation = 0,
	run_job = nil,
}

local errorformat = table.concat({
	"%f:%l:%c: %trror: %m",
	"%f:%l:%c: %tarning: %m",
	"%f:%l:%c: %m",
	"%f:%l: %trror: %m",
	"%f:%l: %tarning: %m",
	"%f:%l: %m",
}, ",")

local function notify(msg, level, title)
	vim.notify(msg, level, { title = title })
end

local function split_lines(text)
	if not text or text == "" then
		return {}
	end
	return vim.split(text, "\n", { plain = true, trimempty = true })
end

local function is_valid_buf(bufnr)
	return bufnr and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr)
end

local function is_valid_win(winid)
	return winid and winid > 0 and vim.api.nvim_win_is_valid(winid)
end

local function sanitize_name(name)
	local safe = name:gsub("[^%w%-_]+", "-")
	safe = safe:gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", "")
	if safe == "" then
		return "main"
	end
	return safe
end

local function build_output_path(source_path)
	local cache_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "cpp-build")
	vim.fn.mkdir(cache_dir, "p")

	local stem = vim.fn.fnamemodify(source_path, ":t:r")
	local hash = vim.fn.sha256(vim.fs.normalize(source_path)):sub(1, 12)
	local exe_name = string.format("%s-%s.exe", sanitize_name(stem), hash)
	return vim.fs.joinpath(cache_dir, exe_name)
end

function M.build_argv(source_path, output_path)
	return {
		"g++",
		"-std=gnu++20",
		"-O2",
		"-Wall",
		"-Wextra",
		source_path,
		"-o",
		output_path or build_output_path(source_path),
	}
end

local function quickfix_from_output(lines, title)
	vim.fn.setqflist({}, " ", {
		title = title,
		lines = lines,
		efm = errorformat,
	})
	vim.cmd("copen")
end

local function panel_name(kind)
	if kind == "input" then
		return "cpp-run://input [F5 submit | Esc editor | Ctrl-Q close]"
	end
	return "cpp-run://output [type = stdin | F5 rerun | q/Ctrl-Q close]"
end

local function remember_input_lines()
	if state.panel_kind == "input" and is_valid_buf(state.panel_bufnr) then
		state.input_lines = vim.api.nvim_buf_get_lines(state.panel_bufnr, 0, -1, false)
	end

	if not state.input_lines or #state.input_lines == 0 then
		state.input_lines = { "" }
	end
end

local function stop_run_job()
	local job = state.run_job
	if not job then
		return true
	end

	state.run_generation = state.run_generation + 1
	state.run_job = nil

	pcall(vim.fn.jobstop, job)
	local waited = vim.fn.jobwait({ job }, 5000)
	if waited[1] == -1 then
		notify("Previous C++ program did not exit; build cancelled.", vim.log.levels.ERROR, "C++ run")
		return false
	end

	return true
end

local function stop_build_system()
	local system = state.build_system
	if not system then
		return true
	end

	state.build_generation = state.build_generation + 1
	state.build_system = nil

	pcall(system.kill, system, 15)
	local ok, res = pcall(system.wait, system, 5000)
	if not ok or not res then
		notify("Previous C++ build did not exit; new build cancelled.", vim.log.levels.ERROR, "C++ build")
		return false
	end

	return true
end

function M.return_to_editor()
	vim.cmd("stopinsert")

	if is_valid_win(state.editor_winid) then
		if is_valid_buf(state.editor_bufnr) and vim.api.nvim_win_get_buf(state.editor_winid) ~= state.editor_bufnr then
			pcall(vim.api.nvim_win_set_buf, state.editor_winid, state.editor_bufnr)
		end
		vim.api.nvim_set_current_win(state.editor_winid)
		return
	end

	if is_valid_buf(state.editor_bufnr) then
		for _, winid in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_get_buf(winid) == state.editor_bufnr then
				vim.api.nvim_set_current_win(winid)
				return
			end
		end
	end
end

function M.close_panel()
	vim.cmd("stopinsert")
	remember_input_lines()
	stop_build_system()
	stop_run_job()

	local panel_winid = state.panel_winid
	local panel_bufnr = state.panel_bufnr
	local focused_panel = (is_valid_win(panel_winid) and vim.api.nvim_get_current_win() == panel_winid)
		or (is_valid_buf(panel_bufnr) and vim.api.nvim_get_current_buf() == panel_bufnr)
	if focused_panel then
		M.return_to_editor()
	end

	if is_valid_win(panel_winid) and #vim.api.nvim_list_wins() > 1 then
		pcall(vim.api.nvim_win_close, panel_winid, true)
	elseif
		is_valid_win(panel_winid)
		and is_valid_buf(panel_bufnr)
		and vim.api.nvim_win_get_buf(panel_winid) == panel_bufnr
	then
		vim.api.nvim_set_current_win(panel_winid)
		vim.cmd("enew")
	end
	if is_valid_buf(panel_bufnr) then
		pcall(vim.api.nvim_buf_delete, panel_bufnr, { force = true })
	end

	state.panel_winid = nil
	state.panel_bufnr = nil
	state.panel_kind = nil
	state.editor_winid = nil
	state.editor_bufnr = nil
	state.source_path = nil
	state.output_path = nil
end

local function set_input_maps(bufnr)
	local opts = { buffer = bufnr, silent = true }
	vim.keymap.set(
		{ "n", "i", "v" },
		"<Esc>",
		M.return_to_editor,
		vim.tbl_extend("force", opts, { desc = "Return to C++ editor" })
	)
	vim.keymap.set(
		{ "n", "i", "v" },
		"<F5>",
		M.submit_input,
		vim.tbl_extend("force", opts, { desc = "Submit C++ input" })
	)
	vim.keymap.set(
		{ "n", "i", "v" },
		"<C-q>",
		M.close_panel,
		vim.tbl_extend("force", opts, { desc = "Close C++ run panel" })
	)
	vim.keymap.set(
		"n",
		"<leader>rp",
		M.toggle_panel_position,
		vim.tbl_extend("force", opts, { desc = "Toggle C++ panel bottom/right" })
	)
end

local function set_output_maps(bufnr)
	local opts = { buffer = bufnr, silent = true }
	vim.keymap.set("n", "<Esc>", M.return_to_editor, vim.tbl_extend("force", opts, { desc = "Return to C++ editor" }))
	vim.keymap.set("n", "<F5>", M.rerun_input, vim.tbl_extend("force", opts, { desc = "Edit C++ input again" }))
	vim.keymap.set("n", "<C-q>", M.close_panel, vim.tbl_extend("force", opts, { desc = "Close C++ run panel" }))
	vim.keymap.set("n", "q", M.close_panel, vim.tbl_extend("force", opts, { desc = "Close C++ run panel" }))
	vim.keymap.set(
		"n",
		"<leader>rp",
		M.toggle_panel_position,
		vim.tbl_extend("force", opts, { desc = "Toggle C++ panel bottom/right" })
	)
	-- Terminal-mode: Esc leaves live typing, F5/Ctrl-Q act like normal mode.
	vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], vim.tbl_extend("force", opts, { desc = "Leave C++ terminal input" }))
	vim.keymap.set("t", "<F5>", M.rerun_input, vim.tbl_extend("force", opts, { desc = "Edit C++ input again" }))
	vim.keymap.set("t", "<C-q>", M.close_panel, vim.tbl_extend("force", opts, { desc = "Close C++ run panel" }))
end

local function apply_panel_size()
	if state.panel_position == "right" then
		vim.cmd("vertical resize 60")
	else
		vim.cmd("resize 15")
	end
end

local function ensure_panel_window()
	if is_valid_win(state.panel_winid) then
		return state.panel_winid
	end

	local base_winid = is_valid_win(state.editor_winid) and state.editor_winid or vim.api.nvim_get_current_win()
	vim.api.nvim_set_current_win(base_winid)
	if state.panel_position == "right" then
		vim.cmd("botright vsplit")
	else
		vim.cmd("botright split")
	end
	apply_panel_size()
	state.panel_winid = vim.api.nvim_get_current_win()
	return state.panel_winid
end

function M.toggle_panel_position()
	state.panel_position = (state.panel_position == "bottom") and "right" or "bottom"
	vim.g.cpp_panel_position = state.panel_position

	if is_valid_win(state.panel_winid) then
		local previous_winid = vim.api.nvim_get_current_win()
		vim.api.nvim_set_current_win(state.panel_winid)
		vim.cmd(state.panel_position == "right" and "wincmd L" or "wincmd J")
		apply_panel_size()
		if previous_winid ~= state.panel_winid and is_valid_win(previous_winid) then
			vim.api.nvim_set_current_win(previous_winid)
		end
	end

	notify("C++ run panel: " .. state.panel_position, vim.log.levels.INFO, "C++ run")
end

local function prepare_panel_buffer(kind, lines)
	local previous_bufnr = state.panel_bufnr
	local winid = ensure_panel_window()
	local bufnr = vim.api.nvim_create_buf(false, true)

	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].bufhidden = "wipe"

	if kind == "input" then
		vim.bo[bufnr].buftype = "nofile"
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, (#lines > 0 and lines or { "" }))
		set_input_maps(bufnr)
	else
		-- Left empty and untyped: submit_input turns it into a terminal buffer.
		set_output_maps(bufnr)
	end

	vim.api.nvim_win_set_buf(winid, bufnr)
	if is_valid_buf(previous_bufnr) and previous_bufnr ~= bufnr then
		pcall(vim.api.nvim_buf_delete, previous_bufnr, { force = true })
	end
	if kind == "input" then
		pcall(vim.api.nvim_buf_set_name, bufnr, panel_name(kind))
	end
	vim.fn.setbufvar(bufnr, "&buflisted", 0)
	state.panel_bufnr = bufnr
	state.panel_winid = winid
	state.panel_kind = kind

	return bufnr, winid
end

-- Input lines to feed the terminal: "\r" is Enter for both ConPTY and Unix
-- ptys (ICRNL). Trailing blank lines are dropped so they don't become extra
-- Enter presses; an all-blank input feeds nothing.
local function input_payload(lines)
	local kept = vim.deepcopy(lines or {})
	while #kept > 0 and kept[#kept] == "" do
		table.remove(kept, #kept)
	end
	if #kept == 0 then
		return ""
	end
	return table.concat(kept, "\r") .. "\r"
end

local function show_input_panel(source_path, output_path, editor_winid, editor_bufnr)
	state.editor_winid = editor_winid
	state.editor_bufnr = editor_bufnr
	state.source_path = source_path
	state.output_path = output_path

	local bufnr, winid = prepare_panel_buffer("input", state.input_lines or { "" })
	vim.api.nvim_set_current_win(winid)
	local last_line = math.max(vim.api.nvim_buf_line_count(bufnr), 1)
	local last_text = vim.api.nvim_buf_get_lines(bufnr, last_line - 1, last_line, false)[1] or ""
	vim.api.nvim_win_set_cursor(winid, { last_line, #last_text })
	vim.cmd("startinsert!")
end

function M.rerun_input()
	if not state.output_path or state.output_path == "" then
		notify("No compiled C++ program is ready to rerun.", vim.log.levels.WARN, "C++ run")
		return
	end
	if not stop_run_job() then
		return
	end

	show_input_panel(state.source_path, state.output_path, state.editor_winid, state.editor_bufnr)
end

function M.submit_input()
	vim.cmd("stopinsert")
	if state.panel_kind ~= "input" or not is_valid_buf(state.panel_bufnr) then
		notify("No C++ input panel is ready to submit.", vim.log.levels.WARN, "C++ run")
		return
	end
	if not state.source_path or state.source_path == "" or not state.output_path or state.output_path == "" then
		notify("No compiled C++ program is ready to run.", vim.log.levels.WARN, "C++ run")
		return
	end

	remember_input_lines()
	if not stop_run_job() then
		return
	end
	if not stop_build_system() then
		return
	end

	local payload = input_payload(state.input_lines)
	local cwd = vim.fn.fnamemodify(state.source_path, ":h")
	state.run_generation = state.run_generation + 1
	local generation = state.run_generation
	local bufnr, winid = prepare_panel_buffer("output")

	-- jobstart(term = true) attaches to the current buffer, so focus the
	-- fresh panel buffer first. Stdin stays open after the pre-fed payload,
	-- which is what makes interactive problems work: keep typing in the
	-- terminal to continue the dialogue.
	vim.api.nvim_set_current_win(winid)
	local job
	local ok, err = pcall(function()
		job = vim.fn.jobstart({ state.output_path }, {
			term = true,
			cwd = cwd,
			on_exit = function(_, code, _)
				vim.schedule(function()
					if generation ~= state.run_generation then
						return
					end

					if state.run_job == job then
						state.run_job = nil
					end
					if code ~= 0 then
						notify(string.format("Program exited with code %d.", code), vim.log.levels.WARN, "C++ run")
					end
				end)
			end,
		})
	end)

	if not ok or not job or job <= 0 then
		state.run_job = nil
		local message = "Failed to start compiled program: " .. tostring(ok and job or err)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { message })
		notify(message, vim.log.levels.ERROR, "C++ run")
		return
	end

	state.run_job = job
	pcall(vim.api.nvim_buf_set_name, bufnr, panel_name("output"))
	if payload ~= "" then
		vim.fn.chansend(job, payload)
	end
	vim.cmd("startinsert")
end

local function compile_current_buffer(on_success)
	vim.cmd("stopinsert")
	remember_input_lines()

	local source_path = vim.api.nvim_buf_get_name(0)
	local source_bufnr = vim.api.nvim_get_current_buf()
	local source_winid = vim.api.nvim_get_current_win()
	if source_path == "" or vim.bo.buftype ~= "" then
		notify("Open a saved C++ source file before compiling.", vim.log.levels.ERROR, "C++ build")
		return
	end
	if not stop_run_job() then
		return
	end
	if not stop_build_system() then
		return
	end

	local wrote, write_error = pcall(vim.cmd, "silent write")
	if not wrote then
		notify("Could not save the C++ source: " .. tostring(write_error), vim.log.levels.ERROR, "C++ build")
		return
	end

	local output_path = build_output_path(source_path)
	local argv = M.build_argv(source_path, output_path)
	local cwd = vim.fn.fnamemodify(source_path, ":h")
	state.build_generation = state.build_generation + 1
	local generation = state.build_generation

	local system
	local ok, err = pcall(function()
		system = vim.system(argv, { text = true, cwd = cwd }, function(res)
			vim.schedule(function()
				if generation ~= state.build_generation then
					return
				end

				if state.build_system == system then
					state.build_system = nil
				end
				if res.code ~= 0 then
					local lines = split_lines((res.stderr or "") ~= "" and res.stderr or res.stdout)
					if #lines == 0 then
						lines = { "Compilation failed with no compiler output." }
					end
					quickfix_from_output(lines, "g++ build")
					notify("Compilation failed. See quickfix for details.", vim.log.levels.ERROR, "C++ build")
					return
				end

				vim.cmd("cclose")
				if on_success then
					on_success(source_path, output_path, source_winid, source_bufnr)
				else
					notify("Build succeeded.", vim.log.levels.INFO, "C++ build")
				end
			end)
		end)
	end)

	if not ok then
		state.build_system = nil
		if generation == state.build_generation then
			notify("Failed to start g++: " .. tostring(err), vim.log.levels.ERROR, "C++ build")
		end
		return
	end
	state.build_system = system
end

function M.build()
	compile_current_buffer(nil)
end

function M.build_and_run()
	compile_current_buffer(show_input_panel)
end

function M.insert_template()
	local bufnr = vim.api.nvim_get_current_buf()
	local current = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	if #current ~= 1 or current[1]:match("%S") then
		notify("C++ template can only be inserted into a blank buffer.", vim.log.levels.WARN, "C++ template")
		return
	end

	local template = {
		'#pragma GCC optimize("O3,unroll-loops")',
		'#pragma GCC target("avx2,bmi,bmi2,lzcnt,popcnt")',
		"#include <bits/stdc++.h>",
		"using namespace std;",
		"",
		"using ll = long long;",
		"using ld = long double;",
		"using pii = pair<int, int>;",
		"using pll = pair<ll, ll>;",
		"using vi = vector<int>;",
		"using vll = vector<ll>;",
		"",
		"const int INF = 1e9;",
		"const ll LINF = 1e18;",
		"const int MOD = 1e9 + 7;",
		"",
		"#define FASTIO ios_base::sync_with_stdio(false);cin.tie(NULL);",
		"#define all(x) (x).begin(), (x).end()",
		"#define sz(x) ((int)(x).size())",
		"#define pb push_back",
		"#define eb emplace_back",
		"#define f first",
		"#define s second",
		"",
		"template<typename T> bool chmin(T& a, const T& b) {",
		"    if (b < a) { a = b; return true; }",
		"    return false;",
		"}",
		"template<typename T> bool chmax(T& a, const T& b) {",
		"    if (a < b) { a = b; return true; }",
		"    return false;",
		"}",
		"",
		"void solve() {",
		"    ",
		"}",
		"",
		"int main() {",
		"    FASTIO;",
		"    int t = 1;",
		"    cin >> t;",
		"    while (t--) {",
		"        solve();",
		"    }",
		"    return 0;",
		"}",
	}

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, template)
	local solve_body_line
	for lnum, line in ipairs(template) do
		if line == "void solve() {" then
			solve_body_line = lnum + 1
			break
		end
	end
	assert(solve_body_line, "C++ template is missing solve()")
	vim.api.nvim_win_set_cursor(0, { solve_body_line, #template[solve_body_line] })
	vim.cmd("startinsert!")
end

local function attach_to_cpp_buffer(bufnr)
	if vim.b[bufnr].cpp_tasks_attached then
		return
	end

	vim.b[bufnr].cpp_tasks_attached = true

	local opts = { buffer = bufnr, silent = true }

	vim.keymap.set(
		{ "n", "i", "v" },
		"<F5>",
		M.build_and_run,
		vim.tbl_extend("force", opts, { desc = "C++: build and run" })
	)
	vim.keymap.set({ "n", "i", "v" }, "<F6>", M.build, vim.tbl_extend("force", opts, { desc = "C++: build only" }))
	vim.keymap.set(
		"n",
		"<leader>it",
		M.insert_template,
		vim.tbl_extend("force", opts, { desc = "C++: insert template" })
	)
	vim.keymap.set("n", "<leader>rx", M.close_panel, vim.tbl_extend("force", opts, { desc = "C++: close run panel" }))
	vim.keymap.set(
		"n",
		"<leader>rp",
		M.toggle_panel_position,
		vim.tbl_extend("force", opts, { desc = "C++: toggle panel bottom/right" })
	)

	vim.api.nvim_buf_create_user_command(bufnr, "CppBuild", M.build, { desc = "Compile current C++ file" })
	vim.api.nvim_buf_create_user_command(
		bufnr,
		"CppBuildRun",
		M.build_and_run,
		{ desc = "Compile and open the C++ input panel" }
	)
	vim.api.nvim_buf_create_user_command(
		bufnr,
		"CppTemplate",
		M.insert_template,
		{ desc = "Insert C++ contest template" }
	)
	vim.api.nvim_buf_create_user_command(
		bufnr,
		"CppClose",
		M.close_panel,
		{ desc = "Stop and close the C++ run panel" }
	)
	vim.api.nvim_buf_create_user_command(
		bufnr,
		"CppPanelSide",
		M.toggle_panel_position,
		{ desc = "Toggle the C++ run panel between bottom and right" }
	)
end

function M.setup()
	if state.setup_done then
		return
	end

	state.setup_done = true

	vim.api.nvim_create_autocmd("FileType", {
		group = augroup,
		pattern = "cpp",
		callback = function(args)
			attach_to_cpp_buffer(args.buf)
		end,
	})

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == "cpp" then
			attach_to_cpp_buffer(bufnr)
		end
	end
end

return M
