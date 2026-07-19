-- ============================================================================
-- options.lua — base editor settings
-- ============================================================================
-- LazyVim auto-loads this file EARLY (before most plugins), which is exactly
-- what we want for things like the leader key and filetype detection.
--
-- These are deliberately plain vim settings ported from my old .vimrc. Note in
-- particular: NO custom motion remaps. I previously ran a custom ijkl movement
-- scheme and dropped it — muscle memory fought every other vim tool. Standard
-- hjkl motions only. See keymaps.lua for the (small) set of maps I do keep.
-- ============================================================================

local opt = vim.opt

opt.background = "light" -- classic gVim uses its light syntax palette
opt.number = true -- show line numbers
opt.belloff = "all" -- no bells, ever (the terminal beep is maddening)

-- Indentation: 4-space soft tabs, the competitive-programming default.
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.softtabstop = 4

-- Allow backspacing over autoindent, line breaks and the start of insert.
opt.backspace = "indent,eol,start"

opt.autoindent = true

opt.undofile = true -- persistent undo across sessions
opt.incsearch = true -- show matches as you type the search
opt.hlsearch = true -- highlight all matches
opt.showmatch = true -- briefly jump to the matching bracket
opt.matchtime = 1 -- ...for 1/10s

-- Use the system clipboard for all yanks/pastes. The official Windows Neovim
-- build bundles win32yank.exe, so this "just works" out of the box — no "+
-- prefix needed, and no extra setup required.
opt.clipboard = "unnamedplus"

-- ----------------------------------------------------------------------------
-- GUI font (Neovide). LazyVim's UI is full of Nerd Font icons; without a Nerd
-- Font they render as ◆?-diamonds. install.ps1 installs JetBrainsMono Nerd
-- Font via winget, whose registered family name is "JetBrainsMono NF" (NOT
-- "JetBrainsMono Nerd Font" — the winget packaging uses the short name).
-- Harmless under terminal nvim, where the terminal's own font applies instead
-- (use a Nerd Font there too — Windows Terminal ships "Cascadia Code NF").
-- ----------------------------------------------------------------------------
vim.o.guifont = "JetBrainsMono NF:h11"

-- Neovide's default cursor interpolates between positions for 150 ms. With a
-- blue cursor highlight that looks like a blue smear, so keep movement direct.
if vim.g.neovide then
	vim.g.neovide_padding_top = 6
	vim.g.neovide_padding_bottom = 0
	vim.g.neovide_padding_left = 4
	vim.g.neovide_padding_right = 4
	vim.g.neovide_position_animation_length = 0
	vim.g.neovide_cursor_animation_length = 0
	vim.g.neovide_cursor_trail_size = 0
	vim.g.neovide_cursor_animate_in_insert_mode = false
	vim.g.neovide_cursor_animate_command_line = false
	vim.g.neovide_cursor_antialiasing = false
	vim.g.neovide_scroll_animation_length = 0
	vim.g.neovide_scroll_animation_far_lines = 0
	vim.g.neovide_cursor_vfx_mode = ""
end

-- ----------------------------------------------------------------------------
-- Filetype: .typ must be recognised as Typst, or tinymist/typst-preview never
-- attach. If `:set filetype?` on a .typ buffer doesn't say "typst", this block
-- isn't loading (see the README troubleshooting section).
-- ----------------------------------------------------------------------------
vim.filetype.add({
	extension = { typ = "typst" },
})
