local action = vim.env.CP_TEMPLATE_BOOTSTRAP_ACTION

local ok, err = xpcall(function()
  local bootstrap = require("config.bootstrap")
  local callback = bootstrap[action]
  if type(callback) ~= "function" then
    error("Unknown bootstrap action: " .. tostring(action))
  end
  callback()
end, debug.traceback)

if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
