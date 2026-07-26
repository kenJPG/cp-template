local java = vim.fn.has("win32") == 1 and "java.exe" or "java"
local javac = vim.fn.has("win32") == 1 and "javac.exe" or "javac"

if vim.fn.executable(java) ~= 1 or vim.fn.executable(javac) ~= 1 then
	print("tests/java_e2e.lua: skipped (Java compiler/runtime not available)")
	return
end

local root = vim.fs.joinpath(vim.fn.stdpath("cache"), "java e2e dir")
local source = vim.fs.joinpath(root, "Main.java")
vim.fn.mkdir(root, "p")
vim.fn.writefile({
	"record Greeting(String value) {}",
	"public class Main {",
	"    public static void main(String[] args) {",
	'        System.out.println(new Greeting("java-17-ok").value());',
	"    }",
	"}",
}, source)

local function cleanup()
	vim.fn.delete(root, "rf")
end

local ok, err = xpcall(function()
	local compiled = vim.system({ javac, "--release", "17", source }, { text = true, cwd = root }):wait()
	assert(compiled.code == 0, compiled.stderr ~= "" and compiled.stderr or compiled.stdout)

	local ran = vim.system({ java, "-cp", root, "Main" }, { text = true, cwd = root }):wait()
	assert(ran.code == 0, ran.stderr ~= "" and ran.stderr or ran.stdout)
	assert(vim.trim(ran.stdout) == "java-17-ok", "unexpected Java output: " .. vim.inspect(ran.stdout))
end, debug.traceback)

cleanup()
if not ok then
	error(err, 0)
end
print("tests/java_e2e.lua: ok")
