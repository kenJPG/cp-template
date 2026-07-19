-- ============================================================================
-- notes.lua -- lightweight note creation and search
-- ============================================================================

local M = {}

local defaults = {
  notes_root = vim.fs.normalize(vim.fn.expand("~/Documents/Notes")),
}

local config = vim.deepcopy(defaults)
local setup_done = false

local function notify(msg, level)
  vim.notify(msg, level, { title = "Notes" })
end

local function slugify(title)
  local slug = title:lower():gsub("[^%w%s%-_]", "")
  slug = slug:gsub("%s+", "-")
  slug = slug:gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", "")
  if slug == "" then
    return "note"
  end
  return slug
end

local function note_template(title, timestamp)
  return table.concat({
    "= " .. title,
    "",
    "Created: " .. timestamp,
    "",
    "== Summary",
    "- ",
    "",
    "== Notes",
    "",
  }, "\n")
end

local function note_path(title)
  local stamp = os.date("%Y-%m-%d-%H%M%S")
  local year = os.date("%Y")
  local month = os.date("%m")
  local dir = vim.fs.joinpath(config.notes_root, "class", year, month)
  local base = string.format("%s-%s", stamp, slugify(title))
  local path = vim.fs.joinpath(dir, base .. ".typ")
  local suffix = 2

  while vim.uv.fs_stat(path) do
    path = vim.fs.joinpath(dir, string.format("%s-%d.typ", base, suffix))
    suffix = suffix + 1
  end

  return path, os.date("%Y-%m-%d %H:%M")
end

local function ensure_parent_dir(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  local ok = vim.fn.mkdir(dir, "p")
  if ok == 0 and vim.fn.isdirectory(dir) == 0 then
    error("Failed to create notes directory: " .. dir)
  end
end

local function create_note(title)
  local trimmed = vim.trim(title or "")
  if trimmed == "" then
    notify("Note creation cancelled.", vim.log.levels.WARN)
    return
  end

  local path, stamp = note_path(trimmed)
  local ok, err = pcall(ensure_parent_dir, path)
  if not ok then
    notify(err, vim.log.levels.ERROR)
    return
  end

  local lines = vim.split(note_template(trimmed, stamp), "\n", { plain = true })
  local wrote, write_result = pcall(vim.fn.writefile, lines, path)
  if not wrote or write_result ~= 0 then
    notify("Failed to write note: " .. path, vim.log.levels.ERROR)
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(path))
end

local function prompt_for_title()
  vim.ui.input({ prompt = "Class note title: " }, function(input)
    if input == nil then
      notify("Note creation cancelled.", vim.log.levels.WARN)
      return
    end
    create_note(input)
  end)
end

local function fallback_picker()
  local files = vim.fs.find(function(name)
    return name:match("%.typ$") or name:match("%.md$")
  end, {
    path = config.notes_root,
    type = "file",
    limit = math.huge,
  })

  table.sort(files)

  if #files == 0 then
    notify("No .typ or .md notes found under " .. config.notes_root, vim.log.levels.WARN)
    return
  end

  local choices = {}
  local choice_to_path = {}
  for _, path in ipairs(files) do
    local label = vim.fs.relpath(config.notes_root, path) or path
    table.insert(choices, label)
    choice_to_path[label] = path
  end

  vim.ui.select(choices, { prompt = "Open note:" }, function(choice)
    if not choice then
      return
    end
    vim.cmd.edit(vim.fn.fnameescape(choice_to_path[choice]))
  end)
end

local function snacks_picker()
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks or not snacks.picker or type(snacks.picker.files) ~= "function" then
    return false
  end

  local picker_ok = pcall(snacks.picker.files, {
    cwd = config.notes_root,
    hidden = true,
    follow = true,
    title = "Notes",
    ft = { "typ", "md" },
    matcher = {
      cwd_bonus = true,
    },
  })

  return picker_ok
end

function M.find_notes()
  if vim.fn.isdirectory(config.notes_root) == 0 then
    notify("Notes root does not exist yet: " .. config.notes_root, vim.log.levels.WARN)
    return
  end

  if snacks_picker() then
    return
  end

  fallback_picker()
end

function M.new_note(title)
  if title and vim.trim(title) ~= "" then
    create_note(title)
    return
  end
  prompt_for_title()
end

function M.setup(opts)
  if setup_done then
    return
  end

  setup_done = true
  config = vim.tbl_deep_extend("force", config, opts or {})

  vim.api.nvim_create_user_command("NotesNew", function(command)
    M.new_note(command.args)
  end, {
    nargs = "*",
    desc = "Create a timestamped Typst class note",
  })

  vim.api.nvim_create_user_command("NotesFind", M.find_notes, {
    desc = "Find existing notes",
  })

  vim.keymap.set("n", "<leader>nn", "<cmd>NotesNew<CR>", { silent = true, desc = "Notes: new class note" })
  vim.keymap.set("n", "<leader>nf", "<cmd>NotesFind<CR>", { silent = true, desc = "Notes: find note" })
end

return M
