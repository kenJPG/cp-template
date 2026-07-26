-- ============================================================================
-- bootstrap.lua -- fail-closed plugin and parser bootstrap for install.cmd
-- ============================================================================

local M = {}

local parsers = {
  "java",
  "lua",
  "markdown",
  "markdown_inline",
  "python",
  "query",
  "vim",
  "vimdoc",
}

local mason_tools = require("config.language_tools")

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
        errors[#errors + 1] =
          string.format("[%s] %s\n%s", plugin.name, task.name or "task", task:output(vim.log.levels.ERROR))
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

local function refresh_mason_registry()
  local registry = require("mason-registry")
  local done = false
  registry.refresh(function()
    done = true
  end)
  if not vim.wait(60000, function()
    return done
  end, 50) then
    die("Mason registry refresh timed out")
  end
  return registry
end

local function install_mason_tools()
  local registry = refresh_mason_registry()
  for _, tool in ipairs(mason_tools) do
    local package = registry.get_package(tool.name)
    if package:is_installing() then
      if not vim.wait(300000, function()
        return not package:is_installing()
      end, 100) then
        die("Mason installation timed out: " .. tool.name)
      end
    end
    if package:get_installed_version() ~= tool.version then
      local done, success, install_error = false, false, nil
      package:install({ version = tool.version }, function(ok, err)
        success = ok
        install_error = err
        done = true
      end)
      if not vim.wait(300000, function()
        return done
      end, 100) then
        die("Mason installation timed out: " .. tool.name)
      end
      if not success then
        die(string.format("Mason failed to install %s@%s: %s", tool.name, tool.version, tostring(install_error)))
      end
    end
  end
end

local function verify_mason_tools()
  local registry = refresh_mason_registry()
  for _, tool in ipairs(mason_tools) do
    local package = registry.get_package(tool.name)
    if not package:is_installed() then
      die("Missing Mason editor tool: " .. tool.name)
    end
    local installed_version = package:get_installed_version()
    if installed_version ~= tool.version then
      die(
        string.format(
          "Wrong Mason editor tool version: %s (expected %s, got %s)",
          tool.name,
          tool.version,
          tostring(installed_version)
        )
      )
    end
    if vim.fn.executable(tool.executable) ~= 1 then
      die(string.format("Mason tool is installed but not executable: %s (%s)", tool.name, tool.executable))
    end
  end
end

function M.install_missing()
  local ok, err = pcall(require("lazy").install, { wait = true, show = false })
  if not ok then
    die(err)
  end

  assert_lazy_clean()
  install_mason_tools()
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
  install_mason_tools()
  verify_parsers()
end

function M.verify_only()
  assert_lazy_clean()
  vim.cmd("Lazy! load all")
  assert_lazy_clean()
  verify_mason_tools()
  verify_parsers()
end

return M
