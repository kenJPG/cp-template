-- ============================================================================
-- bootstrap.lua -- fail-closed plugin and parser bootstrap for install.cmd
-- ============================================================================

local M = {}

local parsers = {
  "lua",
  "markdown",
  "markdown_inline",
  "query",
  "vim",
  "vimdoc",
}

local function die(message)
  if type(message) == "table" then
    message = table.concat(message, "\n")
  end
  vim.api.nvim_err_writeln(tostring(message))
  vim.cmd("cquit 1")
end

local function lazy_task_errors()
  local errors = {}

  for _, plugin in ipairs(require("lazy").plugins()) do
    for _, task in ipairs((plugin._ and plugin._.tasks) or {}) do
      if task.has_errors and task:has_errors() then
        errors[#errors + 1] = string.format(
          "[%s] %s\n%s",
          plugin.name,
          task.name or "task",
          task:output(vim.log.levels.ERROR)
        )
      end
    end
  end

  return errors
end

local function assert_lazy_clean()
  local errors = lazy_task_errors()
  if #errors > 0 then
    die(errors)
  end
end

local function assert_executable(name)
  if vim.fn.executable(name) ~= 1 then
    die("Missing required executable on PATH: " .. name)
  end
end

local function install_parsers()
  assert_executable("tree-sitter")

  local treesitter = require("nvim-treesitter")
  local ok = treesitter.install(parsers, { summary = true }):wait(300000)
  if not ok then
    die("nvim-treesitter parser installation failed")
  end
end

local function verify_parsers()
  local installed = {}
  for _, parser in ipairs(require("nvim-treesitter").get_installed("parsers")) do
    installed[parser] = true
  end

  for _, parser in ipairs(parsers) do
    if not installed[parser] then
      die("Missing tree-sitter parser: " .. parser)
    end
  end
end

function M.install_missing()
  local ok, err = pcall(require("lazy").install, { wait = true, show = false })
  if not ok then
    die(err)
  end

  assert_lazy_clean()
  install_parsers()
  verify_parsers()
end

function M.restore_and_verify()
  local ok, err = pcall(require("lazy").restore, { wait = true, show = false })
  if not ok then
    die(err)
  end

  assert_lazy_clean()
  vim.cmd("Lazy! load all")
  assert_lazy_clean()
  verify_parsers()
end

function M.verify_only()
  assert_lazy_clean()
  vim.cmd("Lazy! load all")
  assert_lazy_clean()
  verify_parsers()
end

return M
