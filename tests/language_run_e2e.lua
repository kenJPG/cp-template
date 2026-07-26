local bootstrap = dofile("tests/bootstrap.lua")

if #vim.api.nvim_list_uis() == 0 then
	local chan = vim.fn.jobstart({ vim.v.progpath, "--embed", "-u", "NONE" }, {
		rpc = true,
		cwd = bootstrap.repo_root,
	})
	if chan <= 0 then
		error("failed to start embedded nvim for the UI-attached language run e2e", 0)
	end
	vim.rpcrequest(chan, "nvim_ui_attach", 120, 35, {})
	local ok, err = pcall(vim.rpcrequest, chan, "nvim_exec_lua", "dofile('tests/language_run_e2e.lua')", {})
	pcall(vim.fn.jobstop, chan)
	if not ok then
		error(err, 0)
	end
	print("tests/language_run_e2e.lua: ok")
	return
end

bootstrap.load_config()
bootstrap.load_autocmds()

local language_run = require("config.language_run")
local root = vim.fs.joinpath(vim.fn.stdpath("cache"), "language run e2e")
vim.fn.mkdir(root, "p")

local function panel_with(marker)
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "language-run" then
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			if table.concat(lines, "\n"):find(marker, 1, true) then
				return bufnr
			end
		end
	end
end

local function panel_count()
	local count = 0
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "language-run" then
			count = count + 1
		end
	end
	return count
end

local function run_file(path, filetype, marker, rerun_while_running)
	vim.cmd.edit(vim.fn.fnameescape(path))
	vim.cmd("setfiletype " .. filetype)
	local source_bufnr = vim.api.nvim_get_current_buf()
	vim.cmd("LanguageRun")
	local completed = vim.wait(60000, function()
		return panel_with(marker) ~= nil
	end, 100)
	if not completed then
		local output = {}
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "language-run" then
				vim.list_extend(output, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
			end
		end
		error(filetype .. " F5 runner did not produce " .. marker .. ": " .. table.concat(output, "\n"), 0)
	end
	if rerun_while_running then
		local first_panel = panel_with(marker)
		language_run.run(source_bufnr)
		assert(
			vim.wait(60000, function()
				local panel = panel_with(marker)
				return panel and panel ~= first_panel
			end, 100),
			filetype .. " F5 rerun did not replace the terminal panel"
		)
		assert(panel_count() == 1, filetype .. " F5 rerun should keep exactly one terminal panel")
	end
	language_run.close_panel()
end

local notifications = {}
local original_notify = vim.notify
vim.notify = function(message, level, opts)
	notifications[#notifications + 1] = tostring(message)
	return original_notify(message, level, opts)
end

local ok, err = xpcall(function()
	local python = vim.fn.has("win32") == 1 and "python.exe" or "python3"
	if vim.fn.executable(python) == 1 or require("config.windows_runtime").python_home() then
		local python_source = vim.fs.joinpath(root, "python file.py")
		vim.fn.writefile({ "import time", 'print("python-f5-ok", flush=True)', "time.sleep(30)" }, python_source)
		run_file(python_source, "python", "python-f5-ok", true)
	else
		print("tests/language_run_e2e.lua: Python skipped (runtime unavailable)")
	end

	local java = vim.fn.has("win32") == 1 and "java.exe" or "java"
	local javac = vim.fn.has("win32") == 1 and "javac.exe" or "javac"
	if vim.fn.executable(java) == 1 and vim.fn.executable(javac) == 1 then
		local java_source = vim.fs.joinpath(root, "Main.java")
		vim.fn.writefile({
			"class Main {",
			"    public static void main(String[] args) {",
			'        System.out.println("java-f5-ok");',
			"    }",
			"}",
		}, java_source)
		run_file(java_source, "java", "java-f5-ok")
	else
		print("tests/language_run_e2e.lua: Java skipped (runtime unavailable)")
	end
end, debug.traceback)

language_run.close_panel()
vim.wait(500)
vim.notify = original_notify
vim.fn.delete(root, "rf")
if not ok then
	error(err, 0)
end
for _, message in ipairs(notifications) do
	assert(
		not message:match("Program exited with code"),
		"intentional stop should not produce an exit warning: " .. message
	)
end
print("tests/language_run_e2e.lua: ok")
