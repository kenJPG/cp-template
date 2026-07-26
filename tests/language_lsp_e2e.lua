require("lazy").load({ plugins = { "mason.nvim" } })

for _, tool in ipairs(require("config.language_tools")) do
	if vim.fn.executable(tool.executable) ~= 1 then
		error("tests/language_lsp_e2e.lua: missing repo-managed tool " .. tool.executable, 0)
	end
end

local root = vim.fs.joinpath(vim.fn.stdpath("cache"), "language lsp e2e")
local java_root = vim.fs.joinpath(root, "java-project")
local java_source = vim.fs.joinpath(java_root, "src", "main", "java", "Main.java")
local python_root = vim.fs.joinpath(root, "python-project")
local python_source = vim.fs.joinpath(python_root, "main.py")

vim.fn.mkdir(vim.fs.dirname(java_source), "p")
vim.fn.mkdir(python_root, "p")
vim.fn.writefile({
	"<project>",
	"  <modelVersion>4.0.0</modelVersion>",
	"  <groupId>test</groupId>",
	"  <artifactId>language-lsp-e2e</artifactId>",
	"  <version>1.0.0</version>",
	"</project>",
}, vim.fs.joinpath(java_root, "pom.xml"))
vim.fn.writefile({
	"public class Main {",
	"    public static void main(String[] args) {",
	'        System.out.println("ok");',
	"    }",
	"}",
}, java_source)
vim.fn.writefile(
	{ "[project]", 'name = "language-lsp-e2e"', 'version = "1.0.0"' },
	vim.fs.joinpath(python_root, "pyproject.toml")
)
vim.fn.writefile({ "value: int = 42", "print(value)" }, python_source)

local function wait_for_client(name, bufnr, timeout)
	return vim.wait(timeout, function()
		return #vim.lsp.get_clients({ name = name, bufnr = bufnr }) > 0
	end, 100)
end

local ok, err = xpcall(function()
	vim.cmd.edit(vim.fn.fnameescape(java_source))
	local java_buf = vim.api.nvim_get_current_buf()
	assert(wait_for_client("jdtls", java_buf, 120000), "JDTLS did not attach to the Maven project")

	vim.cmd.edit(vim.fn.fnameescape(python_source))
	local python_buf = vim.api.nvim_get_current_buf()
	assert(wait_for_client("basedpyright", python_buf, 60000), "BasedPyright did not attach to the Python project")
	assert(wait_for_client("ruff", python_buf, 60000), "Ruff did not attach to the Python project")
end, debug.traceback)

for _, client in ipairs(vim.lsp.get_clients()) do
	client:stop()
end
vim.wait(10000, function()
	return #vim.lsp.get_clients() == 0
end, 100)
vim.fn.delete(root, "rf")

if not ok then
	error(err, 0)
end
print("tests/language_lsp_e2e.lua: ok")
