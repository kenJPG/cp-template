local M = {}

local augroup = vim.api.nvim_create_augroup("cp_template_language_templates", { clear = true })

local java_keywords = {}
for _, word in ipairs({
	"abstract",
	"assert",
	"boolean",
	"break",
	"byte",
	"case",
	"catch",
	"char",
	"class",
	"const",
	"continue",
	"default",
	"do",
	"double",
	"else",
	"enum",
	"exports",
	"extends",
	"false",
	"final",
	"finally",
	"float",
	"for",
	"goto",
	"if",
	"implements",
	"import",
	"instanceof",
	"int",
	"interface",
	"long",
	"module",
	"native",
	"new",
	"non-sealed",
	"null",
	"open",
	"opens",
	"package",
	"permits",
	"private",
	"protected",
	"provides",
	"public",
	"record",
	"requires",
	"return",
	"sealed",
	"short",
	"static",
	"strictfp",
	"super",
	"switch",
	"synchronized",
	"this",
	"throw",
	"throws",
	"to",
	"transient",
	"transitive",
	"true",
	"try",
	"uses",
	"var",
	"void",
	"volatile",
	"when",
	"while",
	"with",
	"yield",
	"_",
}) do
	java_keywords[word] = true
end

local templates = {
	cpp = { file = "cpp.cpp", command = "TemplateCpp", aliases = { "CppTemplate", "TemplateCPP" }, title = "C++ template" },
	java = { file = "java.java", command = "TemplateJava", title = "Java template" },
	python = { file = "python.py", command = "TemplatePython", title = "Python template" },
}

local state = { setup_done = false }

local function notify(message, level, title)
	vim.notify(message, level, { title = title })
end

local function repo_root()
	local config_root = vim.uv.fs_realpath(vim.fn.stdpath("config")) or vim.fn.stdpath("config")
	return vim.fs.dirname(config_root)
end

local function template_path(filetype)
	local meta = templates[filetype]
	assert(meta, "unsupported template filetype: " .. tostring(filetype))
	return vim.fs.joinpath(repo_root(), "templates", meta.file)
end

local function read_template(filetype)
	local path = template_path(filetype)
	local lines = vim.fn.readfile(path)
	if vim.v.shell_error ~= 0 or #lines == 0 then
		error("template file is unavailable: " .. path)
	end
	return lines
end

local function current_java_class_name(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr)
	local stem = vim.fn.fnamemodify(path, ":t:r")
	if stem == "" then
		stem = "Main"
	end
	if java_keywords[stem] or not stem:match("^[$_A-Za-z][$_A-Za-z0-9]*$") then
		error(string.format(
			"Java template needs a valid .java filename stem. '%s' is not a valid public class name.",
			stem
		))
	end
	return stem
end

local function render_lines(filetype, bufnr)
	local lines = read_template(filetype)
	if filetype ~= "java" then
		return lines
	end

	local class_name = current_java_class_name(bufnr)
	for index, line in ipairs(lines) do
		lines[index] = line:gsub("{{CLASS_NAME}}", class_name)
	end
	return lines
end

local function blank_buffer(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	return #lines == 1 and lines[1]:match("^%s*$") ~= nil
end

local function solve_body_cursor(lines)
	for index, line in ipairs(lines) do
		if line:match("solve%b()") then
			local body_line = lines[index + 1]
			if body_line ~= nil then
				return { index + 1, #body_line }
			end
		end
	end
	error("template is missing solve()")
end

function M.insert_template(filetype, bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local meta = templates[filetype]
	assert(meta, "unsupported template filetype: " .. tostring(filetype))

	if not blank_buffer(bufnr) then
		notify(meta.title .. " can only be inserted into a blank buffer.", vim.log.levels.WARN, meta.title)
		return false
	end

	local ok, lines_or_error = pcall(render_lines, filetype, bufnr)
	if not ok then
		notify(tostring(lines_or_error), vim.log.levels.ERROR, meta.title)
		return false
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines_or_error)
	vim.api.nvim_win_set_cursor(0, solve_body_cursor(lines_or_error))
	vim.cmd("startinsert!")
	return true
end

local function command_callback(filetype, bufnr)
	return function()
		M.insert_template(filetype, bufnr)
	end
end

local function attach(bufnr)
	if vim.b[bufnr].language_templates_attached then
		return
	end

	local filetype = vim.bo[bufnr].filetype
	local meta = templates[filetype]
	if not meta then
		return
	end

	vim.b[bufnr].language_templates_attached = true
	local opts = { buffer = bufnr, silent = true, desc = meta.title:gsub(" template$", "") .. ": insert template" }
	vim.keymap.set("n", "<leader>it", command_callback(filetype, bufnr), opts)
	vim.api.nvim_buf_create_user_command(bufnr, meta.command, command_callback(filetype, bufnr), { desc = meta.title })
	for _, alias in ipairs(meta.aliases or {}) do
		vim.api.nvim_buf_create_user_command(bufnr, alias, command_callback(filetype, bufnr), { desc = meta.title })
	end
end

function M.setup()
	if state.setup_done then
		return
	end
	state.setup_done = true

	vim.api.nvim_create_autocmd("FileType", {
		group = augroup,
		pattern = { "cpp", "java", "python" },
		callback = function(args)
			attach(args.buf)
		end,
	})

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			attach(bufnr)
		end
	end
end

return M
