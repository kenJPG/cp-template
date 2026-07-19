local bootstrap = dofile("tests/bootstrap.lua")

bootstrap.load_config()

local notes = require("config.notes")
local test_root = vim.fs.joinpath(vim.fn.stdpath("cache"), "notes e2e path with spaces")

vim.fn.delete(test_root, "rf")
notes.setup({ notes_root = test_root })

local function fail(message)
  error(message, 0)
end

local function assert_true(value, message)
  if not value then
    fail(message)
  end
end

local ok, err = xpcall(function()
  notes.new_note("Linear Algebra")
  notes.new_note("Linear Algebra")

  local files = vim.fs.find(function(name)
    return name:match("%.typ$") ~= nil
  end, { path = test_root, type = "file", limit = 10 })

  assert_true(#files == 2, "same-title notes should create two unique files")
  assert_true(files[1] ~= files[2], "same-title note paths must not collide")

  for _, path in ipairs(files) do
    local text = table.concat(vim.fn.readfile(path), "\n")
    assert_true(text:match("= Linear Algebra") ~= nil, "note template should contain the title")
  end
end, debug.traceback)

vim.fn.delete(test_root, "rf")

if not ok then
  fail(err)
end

print("tests/notes_e2e.lua: ok")
