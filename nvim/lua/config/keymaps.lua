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

-- Clear search highlight.
map("n", "<leader><space>", ":nohlsearch<CR>", { silent = true, desc = "Clear search highlight" })

-- Quit everything without saving.
map("n", "<leader>q", ":qa!<CR>", { silent = true, desc = "Quit all (no save)" })

-- Ctrl-Backspace deletes the previous word, in insert and command-line mode.
-- (Some terminals send <C-h> for Ctrl-Backspace instead; Windows Terminal and
-- PowerShell send <C-BS>, which is what we map here.)
map("i", "<C-BS>", "<C-w>", { noremap = true })
map("c", "<C-BS>", "<C-w>", { noremap = true })
