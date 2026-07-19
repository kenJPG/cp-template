local bootstrap = dofile("tests/bootstrap.lua")

bootstrap.load_config()

if vim.fn.executable("typst") ~= 1 then
  print("tests/typst_e2e.lua: skipped (typst not available)")
  return
end

local function fail(message)
  error(message, 0)
end

local function assert_true(value, message)
  if not value then
    fail(message)
  end
end

local function export_callback()
  local spec = dofile(vim.fs.joinpath(bootstrap.nvim_root, "lua", "plugins", "typst.lua"))
  for _, plugin in ipairs(spec) do
    for _, mapping in ipairs(plugin.keys or {}) do
      if mapping[1] == "<leader>te" and type(mapping[2]) == "function" then
        return mapping[2]
      end
    end
  end
  fail("Typst export mapping was not found")
end

local test_root = vim.fs.joinpath(vim.fn.stdpath("cache"), "typst e2e path with spaces")
local source_path = vim.fs.joinpath(test_root, "math notes.typ")
local pdf_path = vim.fs.joinpath(test_root, "math notes.pdf")

vim.fn.mkdir(test_root, "p")
vim.fn.writefile({
  "= Path-safe export",
  "",
  "The Pythagorean identity is $x^2 + y^2 = z^2$.",
}, source_path)

local function cleanup()
  pcall(vim.fn.delete, test_root, "rf")
end

local original_open = vim.ui.open
local original_notify = vim.notify
local opened_path
local notifications = {}
vim.ui.open = function(path)
  opened_path = path
  return {}
end
vim.notify = function(message)
  table.insert(notifications, tostring(message))
end

local ok, err = xpcall(function()
  vim.cmd("edit " .. vim.fn.fnameescape(source_path))
  export_callback()()

  local exported = vim.wait(20000, function()
    local stat = vim.uv.fs_stat(pdf_path)
    return stat ~= nil and stat.size > 0 and opened_path == pdf_path
  end, 50)

  assert_true(exported, "timed out waiting for Typst PDF export and open callback")

  local original_path = vim.env.PATH
  vim.env.PATH = ""
  export_callback()()
  vim.env.PATH = original_path

  assert_true(
    vim.iter(notifications):any(function(message)
      return message:match("Failed to start Typst") ~= nil
    end),
    "missing Typst executable should produce a notification"
  )
end, debug.traceback)

vim.ui.open = original_open
vim.notify = original_notify
cleanup()

if not ok then
  fail(err)
end

print("tests/typst_e2e.lua: ok")
