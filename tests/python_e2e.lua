local python = vim.fn.has("win32") == 1 and "python.exe" or "python3"

if vim.fn.executable(python) ~= 1 then
	print("tests/python_e2e.lua: skipped (Python not available)")
	return
end

local root = vim.fs.joinpath(vim.fn.stdpath("cache"), "python e2e dir")
local source = vim.fs.joinpath(root, "main.py")
vim.fn.mkdir(root, "p")
vim.fn.writefile({
	"from pathlib import Path",
	"",
	"values: list[int] = [20, 22]",
	'print(f"python-ok:{sum(values)}:{Path.cwd().name}")',
}, source)

local result = vim.system({ python, source }, { text = true, cwd = root }):wait()
vim.fn.delete(root, "rf")
assert(result.code == 0, result.stderr ~= "" and result.stderr or result.stdout)
assert(vim.trim(result.stdout):match("^python%-ok:42:"), "unexpected Python output: " .. vim.inspect(result.stdout))
print("tests/python_e2e.lua: ok")
