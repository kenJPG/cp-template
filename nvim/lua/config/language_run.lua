-- Buffer-local Java/Python run workflow. This intentionally runs the current
-- source file; Maven/Gradle application entrypoints remain project-defined.

local M = {}

local augroup = vim.api.nvim_create_augroup("cp_template_language_run", { clear = true })
local windows_runtime = require("config.windows_runtime")

local state = {
	setup_done = false,
	panel_bufnr = nil,
	panel_winid = nil,
	source_bufnr = nil,
	source_winid = nil,
	job_id = nil,
	run_generation = 0,
}

local function valid_buf(bufnr)
	return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

local function valid_win(winid)
	return winid and vim.api.nvim_win_is_valid(winid)
end

local function notify(message, level)
	vim.notify(message, level, { title = "Run current file" })
end

local function resolve_executable(path)
	if not path or path == "" then
		return nil
	end
	if path:find("[/\\]") then
		local absolute = vim.fn.fnamemodify(path, ":p")
		return vim.fn.executable(absolute) == 1 and vim.fs.normalize(absolute) or nil
	end
	local resolved = vim.fn.exepath(path)
	return resolved ~= "" and vim.fs.normalize(resolved) or nil
end

local function project_root(bufnr, source_path)
	return vim.fs.root(bufnr, { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" })
		or vim.fs.dirname(source_path)
end

local function selected_python()
	local ok, selector = pcall(require, "venv-selector")
	if ok then
		local selected = resolve_executable(selector.python())
		if selected then
			return selected
		end
	end
end

local function python_executable(bufnr, source_path)
	local selected = selected_python()
	if selected then
		return selected
	end

	local root = project_root(bufnr, source_path)
	local python_home = windows_runtime.python_home()
	local candidates = {
		vim.fs.joinpath(root, ".venv", "Scripts", "python.exe"),
		vim.fs.joinpath(root, ".venv", "bin", "python"),
	}
	if python_home then
		candidates[#candidates + 1] = vim.fs.joinpath(python_home, "python.exe")
	end
	if vim.g.python3_host_prog then
		candidates[#candidates + 1] = vim.g.python3_host_prog
	end
	candidates[#candidates + 1] = vim.fn.has("win32") == 1 and "python.exe" or "python3"
	candidates[#candidates + 1] = "python"
	for _, candidate in ipairs(candidates) do
		local resolved = resolve_executable(candidate)
		if resolved then
			return resolved
		end
	end
end

local function java_executable()
	local jdk17 = windows_runtime.temurin_home(17)
	local candidate = jdk17 and vim.fs.joinpath(jdk17, "bin", "java.exe") or nil
	local resolved = resolve_executable(candidate)
	if resolved then
		return resolved
	end
	local fallback = vim.fn.has("win32") == 1 and "java.exe" or "java"
	return resolve_executable(fallback)
end

function M.command_for(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local source_path = vim.api.nvim_buf_get_name(bufnr)
	local filetype = vim.bo[bufnr].filetype
	if source_path == "" or vim.bo[bufnr].buftype ~= "" then
		return nil, nil, "Save the source file before running it."
	end

	if filetype == "python" then
		local python = python_executable(bufnr, source_path)
		if not python then
			return nil, nil, "No Python interpreter is available. Use <leader>cv or create a project .venv."
		end
		return { python, source_path }, project_root(bufnr, source_path), nil
	end

	if filetype == "java" then
		local java = java_executable()
		if not java then
			return nil, nil, "Java is not available. Re-run install.ps1."
		end
		return { java, "--source", "17", source_path }, vim.fs.dirname(source_path), nil
	end

	return nil, nil, "F5 running is only configured for Java and Python here."
end

local function stop_job()
	if not state.job_id then
		return true
	end
	local job_id = state.job_id
	local generation = state.run_generation
	state.run_generation = state.run_generation + 1
	state.job_id = nil
	pcall(vim.fn.jobstop, job_id)
	local waited = vim.fn.jobwait({ job_id }, 3000)
	if waited[1] == -1 then
		state.run_generation = generation
		state.job_id = job_id
		notify("The previous program did not stop; rerun cancelled.", vim.log.levels.ERROR)
		return false
	end
	return true
end

function M.close_panel()
	vim.cmd("stopinsert")
	if not stop_job() then
		return false
	end
	if valid_win(state.panel_winid) and vim.api.nvim_win_get_buf(state.panel_winid) == state.panel_bufnr then
		pcall(vim.api.nvim_win_close, state.panel_winid, true)
	end
	if valid_buf(state.panel_bufnr) then
		pcall(vim.api.nvim_buf_delete, state.panel_bufnr, { force = true })
	end
	state.panel_bufnr = nil
	state.panel_winid = nil
	return true
end

local function return_to_source()
	vim.cmd("stopinsert")
	if valid_win(state.source_winid) and vim.api.nvim_win_get_buf(state.source_winid) == state.source_bufnr then
		vim.api.nvim_set_current_win(state.source_winid)
	elseif valid_buf(state.source_bufnr) then
		for _, winid in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_get_buf(winid) == state.source_bufnr then
				vim.api.nvim_set_current_win(winid)
				return
			end
		end
	end
end

local function open_panel(filetype)
	if not M.close_panel() then
		return false
	end
	vim.cmd("botright 12new")
	state.panel_winid = vim.api.nvim_get_current_win()
	state.panel_bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(state.panel_bufnr, "language-run://" .. filetype)
	vim.bo[state.panel_bufnr].bufhidden = "wipe"
	vim.bo[state.panel_bufnr].swapfile = false

	local opts = { buffer = state.panel_bufnr, silent = true }
	vim.keymap.set("n", "<Esc>", return_to_source, vim.tbl_extend("force", opts, { desc = "Run: return to source" }))
	vim.keymap.set({ "n", "t" }, "<C-q>", M.close_panel, vim.tbl_extend("force", opts, { desc = "Run: close panel" }))
	vim.keymap.set({ "n", "t" }, "<F5>", function()
		M.run(state.source_bufnr)
	end, vim.tbl_extend("force", opts, { desc = "Run: rerun source" }))
	return true
end

function M.run(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not valid_buf(bufnr) then
		return
	end

	local wrote, write_error = pcall(vim.api.nvim_buf_call, bufnr, function()
		vim.cmd("silent write")
	end)
	if not wrote then
		notify("Could not save the source: " .. tostring(write_error), vim.log.levels.ERROR)
		return
	end

	local argv, cwd, command_error = M.command_for(bufnr)
	if not argv then
		notify(command_error, vim.log.levels.ERROR)
		return
	end

	local source_winid = vim.fn.bufwinid(bufnr)
	if not open_panel(vim.bo[bufnr].filetype) then
		return
	end
	state.source_bufnr = bufnr
	state.source_winid = source_winid
	state.run_generation = state.run_generation + 1
	local generation = state.run_generation

	local job_id = vim.fn.termopen(argv, {
		cwd = cwd,
		on_exit = function(id, code)
			vim.schedule(function()
				if generation ~= state.run_generation then
					return
				end
				state.job_id = nil
				if code ~= 0 then
					notify("Program exited with code " .. code .. ".", vim.log.levels.WARN)
				end
			end)
		end,
	})
	if job_id <= 0 then
		M.close_panel()
		notify("Failed to start the program.", vim.log.levels.ERROR)
		return
	end
	state.job_id = job_id
	vim.bo[state.panel_bufnr].filetype = "language-run"
	vim.cmd("startinsert")
end

local function attach(bufnr)
	if vim.b[bufnr].language_run_attached then
		return
	end
	vim.b[bufnr].language_run_attached = true
	local opts = { buffer = bufnr, silent = true }
	local language = vim.bo[bufnr].filetype == "java" and "Java" or "Python"
	vim.keymap.set({ "n", "i", "v" }, "<F5>", function()
		M.run(bufnr)
	end, vim.tbl_extend("force", opts, { desc = language .. ": run current file" }))
	vim.keymap.set("n", "<leader>rx", M.close_panel, vim.tbl_extend("force", opts, { desc = "Run: close panel" }))
	vim.api.nvim_buf_create_user_command(bufnr, "LanguageRun", function()
		M.run(bufnr)
	end, { desc = "Run current Java/Python file" })
	vim.api.nvim_buf_create_user_command(
		bufnr,
		"LanguageRunClose",
		M.close_panel,
		{ desc = "Close language run panel" }
	)
end

function M.setup()
	if state.setup_done then
		return
	end
	state.setup_done = true
	vim.api.nvim_create_autocmd("FileType", {
		group = augroup,
		pattern = { "java", "python" },
		callback = function(args)
			attach(args.buf)
		end,
	})
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.tbl_contains({ "java", "python" }, vim.bo[bufnr].filetype) then
			attach(bufnr)
		end
	end
end

return M
