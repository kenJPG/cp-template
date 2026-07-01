-- ============================================================================
-- keymaps.lua — custom key mappings
-- ============================================================================
-- LazyVim auto-loads this on the VeryLazy event, AFTER its own default maps, so
-- anything set here overrides LazyVim. Standard vim motions are kept as-is:
-- I do NOT remap h/j/k/l or i (dropped my old ijkl scheme deliberately).
--
-- The old `<Leader>r` "re-source vimrc" map is intentionally gone: under
-- lazy.nvim re-sourcing config doesn't cleanly reload plugin state, so the
-- correct way to reload is to just restart Neovim.
-- ============================================================================

local map = vim.keymap.set

-- ----------------------------------------------------------------------------
-- Toggle a leading `//` line comment, then clear search highlight.
-- Implemented as a :range command so it works uniformly for the current line
-- (normal mode) and a selection (visual mode, where `:` auto-inserts '<,'>).
-- ----------------------------------------------------------------------------
local function toggle_comment(line1, line2)
  for lnum = line1, line2 do
    local line = vim.fn.getline(lnum)
    if line:match("^%s*//") then
      -- Uncomment: strip the first `//` (and one following space if present).
      line = line:gsub("^(%s*)//%s?", "%1", 1)
      vim.fn.setline(lnum, line)
    elseif line:match("%S") then
      -- Comment: insert `// ` at the first non-blank column.
      line = line:gsub("^(%s*)", "%1// ", 1)
      vim.fn.setline(lnum, line)
    end
    -- Blank lines are left untouched.
  end
  vim.cmd("nohlsearch")
end

vim.api.nvim_create_user_command("ToggleComment", function(o)
  toggle_comment(o.line1, o.line2)
end, { range = true })

map("n", "<leader>c", ":ToggleComment<CR>", { silent = true, desc = "Toggle // comment" })
map("x", "<leader>c", ":ToggleComment<CR>", { silent = true, desc = "Toggle // comment" })

-- ----------------------------------------------------------------------------
-- Competitive-programming build + run: <F5>
-- Save, compile with g++, and on success run the binary in a terminal split so
-- program output is visible AND interactive (stdin works). A blocking `:!`
-- would take over the whole screen and can't feed a REPL-style program well.
-- Bound in normal, insert and visual mode.
-- ----------------------------------------------------------------------------
local function build_and_run()
  vim.cmd("stopinsert") -- in case we were triggered from insert mode
  vim.cmd("silent! write")

  local src = vim.fn.expand("%:p")
  local bin = vim.fn.expand("%:p:r") -- same path, extension stripped (Linux: no .exe)

  -- Compile synchronously so we know whether to run.
  local res = vim.system(
    { "g++", "-std=c++17", "-O2", "-Wall", src, "-o", bin },
    { text = true }
  ):wait()

  if res.code ~= 0 then
    -- Surface compiler errors without launching the program.
    vim.notify(
      (res.stderr ~= "" and res.stderr or res.stdout) or "compilation failed",
      vim.log.levels.ERROR,
      { title = "g++ (F5)" }
    )
    return
  end

  -- Run in a short terminal split at the bottom. terminal buffers are fully
  -- interactive, so we can type input and scroll output while Neovim stays live.
  vim.cmd("botright split")
  vim.cmd("resize 15")
  vim.cmd("terminal " .. vim.fn.fnameescape(bin))
  vim.cmd("startinsert") -- drop straight into the terminal for stdin
end

map({ "n", "i", "v" }, "<F5>", build_and_run, { desc = "C++: build & run" })

-- <F6>: save and :make (uses the g++ makeprg set for cpp buffers in options.lua).
map("n", "<F6>", ":w<CR>:make<CR>", { silent = true, desc = "Save & :make" })

-- Clear search highlight.
map("n", "<leader><space>", ":nohlsearch<CR>", { silent = true, desc = "Clear search highlight" })

-- Quit everything without saving.
map("n", "<leader>q", ":qa!<CR>", { silent = true, desc = "Quit all (no save)" })

-- Ctrl-Backspace deletes the previous word, in insert and command-line mode.
-- (Some terminals send <C-h> for Ctrl-Backspace; WezTerm sends <C-BS>, which is
-- what we map here.)
map("i", "<C-BS>", "<C-w>", { noremap = true })
map("c", "<C-BS>", "<C-w>", { noremap = true })

-- ----------------------------------------------------------------------------
-- Install the custom smart auto-pair engine. Kept in its own module
-- (config/autopairs.lua); mini.pairs is disabled in plugins/editor.lua.
-- ----------------------------------------------------------------------------
require("config.autopairs").setup()
