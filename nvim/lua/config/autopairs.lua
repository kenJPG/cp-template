-- ============================================================================
-- autopairs.lua — custom "smart" auto-pairing engine
-- ============================================================================
-- This is a direct Lua port of the auto-pair engine from my old .vimrc. I use
-- THIS instead of mini.pairs (which LazyVim ships by default) because I want
-- these specific behaviours — mini.pairs is disabled in lua/plugins/editor.lua.
--
-- Behaviours:
--   * Smart open  ( [ {  : only auto-close when it won't wrap existing text,
--                         i.e. at end-of-line or before whitespace/a closer.
--                         Typing "(" just before `myVar` must NOT give "()myVar".
--   * Smart close ) ] }  : if the matching closer is already the next char,
--                         step over it instead of inserting a duplicate.
--   * Smart quote ' "    : same step-over logic; and a single quote after a
--                         letter is treated as an apostrophe (don't -> no pair).
--   * Smart <BS>         : between an empty pair ({}, [], (), "", '') delete both.
--   * Smart <CR>         : between { and } expand into an indented block.
--
-- Everything is implemented as <expr> insert-mode maps: each function returns
-- the keystrokes Neovim should insert, so it composes with undo/repeat cleanly.
--
-- Call require("config.autopairs").setup() to install the maps (done from the
-- bottom of keymaps.lua).
-- ============================================================================

local M = {}

-- Helpers ---------------------------------------------------------------------

-- Character immediately AFTER the cursor ("" if the cursor is at EOL).
local function next_char()
  local col = vim.fn.col(".")          -- 1-based, position the cursor is at
  local line = vim.fn.getline(".")
  return line:sub(col, col)
end

-- Character immediately BEFORE the cursor ("" if at column 1).
local function prev_char()
  local col = vim.fn.col(".")
  local line = vim.fn.getline(".")
  return line:sub(col - 1, col - 1)
end

-- True when it's safe to drop a closing pair here: at EOL, or the next char is
-- whitespace or one of the closing brackets. Mirrors the old SmartOpen guard.
local function safe_to_pair()
  local nc = next_char()
  return nc == "" or nc:match("[%s%)%]}]") ~= nil
end

-- Smart open ------------------------------------------------------------------

function M.open(open, close)
  if safe_to_pair() then
    return open .. close .. "<Left>"
  end
  return open
end

-- Smart close -----------------------------------------------------------------

function M.close(close)
  if next_char() == close then
    return "<Right>"
  end
  return close
end

-- Smart quote -----------------------------------------------------------------

function M.quote(q)
  -- Step over an existing quote of the same kind.
  if next_char() == q then
    return "<Right>"
  end
  -- Single quote right after a letter -> apostrophe/contraction, don't pair.
  if q == "'" and prev_char():match("%a") then
    return q
  end
  -- Otherwise apply the same "only pair when safe" rule as brackets.
  if safe_to_pair() then
    return q .. q .. "<Left>"
  end
  return q
end

-- Smart backspace -------------------------------------------------------------

local EMPTY_PAIRS = {
  ["{"] = "}",
  ["["] = "]",
  ["("] = ")",
  ['"'] = '"',
  ["'"] = "'",
}

function M.backspace()
  local prev = prev_char()
  if EMPTY_PAIRS[prev] and next_char() == EMPTY_PAIRS[prev] then
    -- Cursor sits between an empty pair: delete the closer (<Del>) then the
    -- opener (<BS>).
    return "<Del><BS>"
  end
  return "<BS>"
end

-- Smart enter -----------------------------------------------------------------

function M.enter()
  if prev_char() == "{" and next_char() == "}" then
    -- Expand {|} into:
    --   {
    --       |
    --   }
    -- <CR> opens the block, <Esc> leaves insert, O opens an indented line above
    -- the closing brace (cindent handles the indentation).
    return "<CR><Esc>O"
  end
  return "<CR>"
end

-- Install the maps ------------------------------------------------------------

function M.setup()
  local map = function(lhs, fn)
    -- expr = true means the function's RETURN value is the text to insert;
    -- replace_keycodes lets us return "<Left>", "<CR>" etc. as literal keys.
    vim.keymap.set("i", lhs, fn, { expr = true, noremap = true, replace_keycodes = true, silent = true })
  end

  map("(", function() return M.open("(", ")") end)
  map("[", function() return M.open("[", "]") end)
  map("{", function() return M.open("{", "}") end)

  map(")", function() return M.close(")") end)
  map("]", function() return M.close("]") end)
  map("}", function() return M.close("}") end)

  map("'", function() return M.quote("'") end)
  map('"', function() return M.quote('"') end)

  map("<BS>", function() return M.backspace() end)
  map("<CR>", function() return M.enter() end)
end

return M
