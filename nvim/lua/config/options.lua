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

opt.number = true          -- show line numbers
opt.belloff = "all"        -- no bells, ever (the terminal beep is maddening)

-- Indentation: 4-space soft tabs, the competitive-programming default.
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.softtabstop = 4

-- Allow backspacing over autoindent, line breaks and the start of insert.
opt.backspace = "indent,eol,start"

-- C/C++ aware indentation. cinoptions is tuned so switch/case, function args
-- and continuation lines line up the way I like for contest code.
opt.autoindent = true
opt.cindent = true
opt.cinoptions = "{0,1s,t0,n-2,p2s,(03s,=.5s,>1s,=1s,:1s"

opt.undofile = true        -- persistent undo across sessions
opt.incsearch = true       -- show matches as you type the search
opt.hlsearch = true        -- highlight all matches
opt.showmatch = true       -- briefly jump to the matching bracket
opt.matchtime = 1          -- ...for 1/10s

-- Use the system clipboard for all yanks/pastes. On WSL this is bridged to the
-- real Windows clipboard by win32yank.exe (see wsl/clipboard-bridge.sh), so
-- "just yank" works — no "+ prefix needed.
opt.clipboard = "unnamedplus"

-- Leader is also set in init.lua (before plugins load); repeated here so this
-- file remains self-contained if read on its own.
vim.g.mapleader = " "

-- ----------------------------------------------------------------------------
-- Filetype: .typ must be recognised as Typst, or tinymist/typst-preview never
-- attach. If `:set filetype?` on a .typ buffer doesn't say "typst", this block
-- isn't loading (see the README troubleshooting section).
-- ----------------------------------------------------------------------------
vim.filetype.add({
  extension = { typ = "typst" },
})

-- ----------------------------------------------------------------------------
-- makeprg for C++ so <F6> (:make) compiles the current file. <F5> uses its own
-- vim.system-based build+run (see keymaps.lua); this is the lighter :make path.
-- Set per-buffer on the cpp filetype so it doesn't leak into Typst buffers.
-- %< expands to the current filename without its extension.
-- ----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  pattern = "cpp",
  callback = function()
    vim.opt_local.makeprg = "g++ -std=c++17 -O2 -Wall % -o %<"
  end,
})
