-- ============================================================================
-- init.lua — entry point for the LazyVim-based config
-- ============================================================================
-- This file is symlinked to %LOCALAPPDATA%\nvim by install.ps1, so editing it
-- in the repo takes effect live (after restarting Neovim).
--
-- What happens here, in order:
--   1. Set the leader keys BEFORE any plugin loads. which-key and lazy.nvim
--      capture the leader at load time, so setting it late means mappings get
--      registered against the wrong key. This is why it lives at the very top.
--   2. Bootstrap lazy.nvim (clone it on first launch if it isn't present).
--   3. Hand off to lazy.nvim, importing LazyVim's plugin set plus our own
--      overrides in lua/plugins/.
--
-- Note: LazyVim itself is responsible for auto-loading lua/config/options.lua,
-- lua/config/keymaps.lua and lua/config/autocmds.lua at the right moments
-- (options early, keymaps/autocmds on the VeryLazy event so they override
-- LazyVim's own defaults). We do NOT require those files by hand here.
-- ============================================================================

-- 1. Leader keys (space as leader, backslash as local leader).
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- 2. Bootstrap lazy.nvim.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local repo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--branch=stable",
		repo,
		lazypath,
	})
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit...", "MoreMsg" },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- 3. Configure lazy.nvim + LazyVim.
require("lazy").setup({
	spec = {
		-- LazyVim core: brings in sane defaults, LSP wiring, Treesitter, Telescope/
		-- snacks pickers, which-key, etc. We layer our overrides on top.
		{ "LazyVim/LazyVim", import = "lazyvim.plugins" },
		-- Our own plugin specs / overrides (lua/plugins/*.lua).
		{ import = "plugins" },
	},
	defaults = {
		-- LazyVim recommends eager-loading its own plugins and always using the
		-- latest git commit for plugins that don't tag releases.
		lazy = false,
		version = false,
	},
	-- When plugins are missing on a fresh install, load the light theme so the
	-- first-run headless sync (and the first real launch) look sane.
	install = { colorscheme = { "vim", "default" } },
	-- Background update checker; silent so it doesn't nag on every launch.
	checker = { enabled = true, notify = false },
	performance = {
		rtp = {
			-- Disable some built-in plugins we don't use for a faster startup.
			disabled_plugins = {
				"gzip",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
})
