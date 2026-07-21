local bootstrap = dofile("tests/bootstrap.lua")

if vim.fn.executable("g++") ~= 1 then
	print("tests/cpp_e2e.lua: skipped (g++ not available)")
	return
end

-- ConPTY only delivers terminal stdin once a UI is attached, so the run
-- terminal cannot be driven from a plain --headless process. Re-run this
-- file inside an embedded nvim that has a (virtual) UI attached.
if #vim.api.nvim_list_uis() == 0 then
	local chan = vim.fn.jobstart({ vim.v.progpath, "--embed", "-u", "NONE" }, {
		rpc = true,
		cwd = bootstrap.repo_root,
	})
	if chan <= 0 then
		error("failed to start embedded nvim for the UI-attached C++ e2e run", 0)
	end
	vim.rpcrequest(chan, "nvim_ui_attach", 120, 35, {})
	local ok, err = pcall(vim.rpcrequest, chan, "nvim_exec_lua", "dofile('tests/cpp_e2e.lua')", {})
	pcall(vim.fn.jobstop, chan)
	if not ok then
		error(err, 0)
	end
	print("tests/cpp_e2e.lua: ok")
	return
end

bootstrap.load_config()
bootstrap.load_autocmds()

local cpp_tasks = require("config.cpp_tasks")

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

local function has_map(bufnr, mode, lhs, desc)
	for _, map in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
		if map.lhs == lhs and (desc == nil or map.desc == desc) then
			return true
		end
	end
	return false
end

local function find_panel(kind)
	local prefix = "cpp-run://" .. kind
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local name = vim.api.nvim_buf_get_name(bufnr)
			if vim.startswith(name, prefix) then
				return bufnr, vim.fn.bufwinid(bufnr)
			end
		end
	end
	return nil, -1
end

local function wait_for_panel(kind, timeout_ms)
	local panel_bufnr, panel_winid
	local ready = vim.wait(timeout_ms, function()
		panel_bufnr, panel_winid = find_panel(kind)
		return panel_bufnr ~= nil and panel_winid > 0
	end, 50)
	return ready, panel_bufnr, panel_winid
end

local function panel_text(bufnr)
	return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

local test_root = vim.fs.joinpath(vim.fn.stdpath("cache"), "cpp e2e dir")
local source_dir = vim.fs.joinpath(test_root, "source with spaces")
local source_path = vim.fs.joinpath(source_dir, "double input.cpp")
local output_path = cpp_tasks.build_argv(source_path)[8]

vim.fn.mkdir(source_dir, "p")
vim.fn.writefile({
	"#include <chrono>",
	"#include <iostream>",
	"#include <thread>",
	"int main() {",
	"  long long n = 0, sum = 0, x = 0;",
	"  std::cin >> n;",
	"  for (long long i = 0; i < n; ++i) {",
	"    std::cin >> x;",
	"    sum += x;",
	"  }",
	"  std::this_thread::sleep_for(std::chrono::milliseconds(1200));",
	"  std::cout << (sum * 2) << std::endl;",
	"  return 0;",
	"}",
}, source_path)

local function cleanup()
	pcall(vim.fn.delete, source_path)
	pcall(vim.fn.delete, source_dir, "rf")
	pcall(vim.fn.delete, test_root, "rf")
	pcall(vim.fn.delete, output_path)
end

local ok, err = xpcall(function()
	vim.cmd("edit " .. vim.fn.fnameescape(source_path))
	vim.cmd("setfiletype cpp")
	local source_bufnr = vim.api.nvim_get_current_buf()
	local source_winid = vim.api.nvim_get_current_win()

	cpp_tasks.build_and_run()

	local input_ready, input_bufnr, input_winid = wait_for_panel("input", 20000)
	assert_true(input_ready, "timed out waiting for the C++ input panel after build_and_run")
	assert_equal(
		vim.api.nvim_get_option_value("buftype", { buf = input_bufnr }),
		"nofile",
		"input panel should use nofile"
	)
	assert_equal(
		vim.api.nvim_get_option_value("swapfile", { buf = input_bufnr }),
		false,
		"input panel should disable swap"
	)
	assert_equal(
		vim.api.nvim_get_option_value("modifiable", { buf = input_bufnr }),
		true,
		"input panel should be editable"
	)
	assert_equal(vim.fn.buflisted(input_bufnr), 0, "input panel should stay unlisted")
	assert_true(has_map(input_bufnr, "n", "<Esc>", "Return to C++ editor"), "input Escape mapping should exist")
	assert_true(has_map(input_bufnr, "i", "<Esc>", "Return to C++ editor"), "input insert Escape mapping should exist")
	assert_true(has_map(input_bufnr, "n", "<F5>", "Submit C++ input"), "input F5 submit mapping should exist")
	assert_true(has_map(input_bufnr, "i", "<F5>", "Submit C++ input"), "input insert F5 submit mapping should exist")
	assert_true(has_map(input_bufnr, "n", "<C-Q>", "Close C++ run panel"), "input Ctrl-Q close mapping should exist")
	assert_true(
		has_map(input_bufnr, "i", "<C-Q>", "Close C++ run panel"),
		"input insert Ctrl-Q close mapping should exist"
	)

	-- Panel position toggle: bottom split (col layout) <-> right split (row layout).
	assert_equal(vim.fn.winlayout()[1], "col", "run panel should start as a bottom split")
	cpp_tasks.toggle_panel_position()
	assert_equal(vim.fn.winlayout()[1], "row", "toggling should move the run panel to the right side")
	assert_true(vim.api.nvim_win_is_valid(input_winid), "toggling position should keep the panel window alive")
	cpp_tasks.toggle_panel_position()
	assert_equal(vim.fn.winlayout()[1], "col", "toggling again should move the run panel back to the bottom")

	vim.api.nvim_set_current_win(input_winid)
	cpp_tasks.return_to_editor()
	local returned_to_editor = vim.wait(1000, function()
		return vim.api.nvim_get_current_win() == source_winid and vim.api.nvim_get_current_buf() == source_bufnr
	end, 10)
	assert_true(returned_to_editor, "input panel Escape did not focus the launching C++ editor")

	vim.api.nvim_set_current_win(input_winid)
	vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, false, { "2", "10 11" })
	cpp_tasks.submit_input()

	local output_ready, output_bufnr, output_winid = wait_for_panel("output", 5000)
	assert_true(output_ready, "timed out waiting for the C++ run terminal after submitting input")
	assert_equal(
		vim.api.nvim_get_option_value("buftype", { buf = output_bufnr }),
		"terminal",
		"run panel should be a terminal buffer"
	)
	assert_equal(
		vim.api.nvim_get_option_value("modifiable", { buf = output_bufnr }),
		false,
		"run terminal should not be text-editable"
	)
	assert_true(has_map(output_bufnr, "n", "<Esc>", "Return to C++ editor"), "output Escape mapping should exist")
	assert_true(has_map(output_bufnr, "n", "<F5>", "Edit C++ input again"), "output F5 rerun mapping should exist")
	assert_true(has_map(output_bufnr, "n", "q", "Close C++ run panel"), "output q close mapping should exist")
	assert_true(has_map(output_bufnr, "n", "<C-Q>", "Close C++ run panel"), "output Ctrl-Q close mapping should exist")
	assert_true(has_map(output_bufnr, "t", "<Esc>"), "terminal Escape mapping should exist")
	assert_true(has_map(output_bufnr, "t", "<F5>", "Edit C++ input again"), "terminal F5 rerun mapping should exist")
	assert_true(
		has_map(output_bufnr, "t", "<C-Q>", "Close C++ run panel"),
		"terminal Ctrl-Q close mapping should exist"
	)

	local saw_answer = vim.wait(10000, function()
		return panel_text(output_bufnr):match("42") ~= nil
	end, 50)
	assert_true(saw_answer, "timed out waiting for output containing 42")

	vim.api.nvim_set_current_win(output_winid)
	cpp_tasks.return_to_editor()
	local output_returned = vim.wait(1000, function()
		return vim.api.nvim_get_current_win() == source_winid and vim.api.nvim_get_current_buf() == source_bufnr
	end, 10)
	assert_true(output_returned, "output panel Escape did not focus the launching C++ editor")

	vim.api.nvim_set_current_win(output_winid)
	cpp_tasks.rerun_input()

	local rerun_input_ready, rerun_input_bufnr, rerun_input_winid = wait_for_panel("input", 5000)
	assert_true(rerun_input_ready, "output F5 rerun did not restore the input panel")
	assert_equal(
		vim.api.nvim_buf_get_lines(rerun_input_bufnr, 0, -1, false),
		{ "2", "10 11" },
		"rerun input panel should preserve the last submitted stdin"
	)

	cpp_tasks.return_to_editor()
	assert_true(
		vim.api.nvim_get_current_win() == source_winid and vim.api.nvim_get_current_buf() == source_bufnr,
		"returning from rerun input should focus the original source buffer"
	)

	cpp_tasks.build_and_run()
	local repeat_source_ready, repeat_source_bufnr, repeat_source_winid = wait_for_panel("input", 20000)
	assert_true(repeat_source_ready, "repeating source F5 should reopen the same-path input panel")
	assert_equal(
		vim.api.nvim_buf_get_lines(repeat_source_bufnr, 0, -1, false),
		{ "2", "10 11" },
		"repeating source F5 should preserve the previous input text"
	)

	vim.api.nvim_set_current_win(repeat_source_winid)
	cpp_tasks.submit_input()
	local running_output_ready, running_output_bufnr, running_output_winid = wait_for_panel("output", 5000)
	assert_true(running_output_ready, "submitting preserved input should reopen the output panel")
	assert_equal(
		vim.api.nvim_get_option_value("buftype", { buf = running_output_bufnr }),
		"terminal",
		"resubmitting should start a fresh run terminal"
	)

	cpp_tasks.return_to_editor()
	cpp_tasks.build_and_run()
	local replaced_input_ready, replaced_input_bufnr, replaced_input_winid = wait_for_panel("input", 20000)
	assert_true(replaced_input_ready, "rebuilding while the previous program runs should still reopen input")
	assert_equal(
		vim.api.nvim_buf_get_lines(replaced_input_bufnr, 0, -1, false),
		{ "2", "10 11" },
		"rebuild after cancelling a running program should keep the last input"
	)

	local stale_callback_ignored = vim.wait(2500, function()
		local current_bufnr, current_winid = find_panel("input")
		return current_bufnr == replaced_input_bufnr
			and current_winid == replaced_input_winid
			and panel_text(replaced_input_bufnr) == "2\n10 11"
	end, 50)
	assert_true(stale_callback_ignored, "stale run callback should not replace the fresh input panel after source F5")

	-- Interactive problem flow: submit with no pre-fed input, then answer the
	-- waiting program by typing into the live terminal (via its job channel).
	vim.api.nvim_set_current_win(replaced_input_winid)
	vim.api.nvim_buf_set_lines(replaced_input_bufnr, 0, -1, false, { "" })
	cpp_tasks.submit_input()
	local empty_output_ready, empty_output_bufnr, empty_output_winid = wait_for_panel("output", 5000)
	assert_true(empty_output_ready, "empty stdin should still open the run terminal")
	local interactive_job = vim.b[empty_output_bufnr].terminal_job_id
	assert_true(interactive_job ~= nil, "run terminal should expose its job channel")
	vim.fn.chansend(interactive_job, "2\r20 1\r")
	local interactive_done = vim.wait(10000, function()
		return panel_text(empty_output_bufnr):match("\n42") ~= nil
	end, 50)
	assert_true(interactive_done, "typing into the live terminal should reach the program's stdin")

	vim.api.nvim_set_current_win(empty_output_winid)
	cpp_tasks.close_panel()
	assert_true(not vim.api.nvim_win_is_valid(empty_output_winid), "closing the C++ run panel should remove its window")
	assert_true(not vim.api.nvim_buf_is_valid(empty_output_bufnr), "closing the C++ run panel should delete its buffer")
	assert_true(
		vim.api.nvim_get_current_win() == source_winid and vim.api.nvim_get_current_buf() == source_bufnr,
		"closing the focused output panel should restore the source editor"
	)

	-- Runtime failures must remain visible in the panel instead of relying on a
	-- transient notification. stderr should stay directly above the footer.
	vim.api.nvim_buf_set_lines(source_bufnr, 0, -1, false, {
		"#include <iostream>",
		"int main() {",
		'  std::cerr << "runtime boom\\n";',
		"  return 7;",
		"}",
	})
	cpp_tasks.build_and_run()
	local failure_input_ready, _, failure_input_winid = wait_for_panel("input", 20000)
	assert_true(failure_input_ready, "runtime failure fixture did not compile")
	vim.api.nvim_set_current_win(failure_input_winid)
	cpp_tasks.submit_input()
	local failure_output_ready, failure_output_bufnr, failure_output_winid = wait_for_panel("output", 5000)
	assert_true(failure_output_ready, "runtime failure did not open the output terminal")
	local failure_visible = vim.wait(10000, function()
		local text = panel_text(failure_output_bufnr)
		return text:find("runtime boom", 1, true)
			and text:find("[runtime error]", 1, true)
			and text:find("Program exited with code 7.", 1, true)
	end, 50)
	assert_true(failure_visible, "stderr and nonzero exit status should remain visible in the run panel")
	assert_equal(
		vim.api.nvim_get_option_value("modifiable", { buf = failure_output_bufnr }),
		false,
		"runtime failure footer should leave the terminal read-only"
	)
	assert_equal(
		vim.api.nvim_win_get_cursor(failure_output_winid)[1],
		vim.api.nvim_buf_line_count(failure_output_bufnr),
		"runtime failure panel should scroll to the diagnostic footer"
	)
	vim.api.nvim_set_current_win(failure_output_winid)
	cpp_tasks.close_panel()

	cpp_tasks.build_and_run()
	cpp_tasks.close_panel()
	local cancelled_build_stayed_closed = vim.wait(2500, function()
		local input_bufnr = find_panel("input")
		local output_bufnr = find_panel("output")
		return input_bufnr == nil and output_bufnr == nil
	end, 50)
	assert_true(cancelled_build_stayed_closed, "closing during compilation should not reopen a stale run panel")

	vim.cmd("vnew")
	local unrelated_winid = vim.api.nvim_get_current_win()
	local unrelated_bufnr = vim.api.nvim_get_current_buf()
	cpp_tasks.close_panel()
	assert_true(
		vim.api.nvim_get_current_win() == unrelated_winid,
		"closing an absent run panel should not change windows"
	)
	assert_true(
		vim.api.nvim_get_current_buf() == unrelated_bufnr,
		"closing an absent run panel should not change buffers"
	)
end, debug.traceback)

cleanup()

if not ok then
	fail(err)
end

print("tests/cpp_e2e.lua: ok")
