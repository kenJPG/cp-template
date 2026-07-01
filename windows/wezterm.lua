-- ============================================================================
-- wezterm.lua — WezTerm terminal configuration
-- ============================================================================
-- windows/install.ps1 copies this to %USERPROFILE%\.wezterm.lua.
--
-- WezTerm is chosen because it's GPU-accelerated AND implements the kitty
-- graphics protocol, which is what lets typst-preview.nvim render inline images
-- inside Neovim. The default domain launches straight into WSL Ubuntu, so
-- opening WezTerm drops you directly where all the dev tooling lives.
-- ============================================================================

local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Launch straight into the WSL Ubuntu distro instead of PowerShell.
-- WezTerm auto-registers a domain per installed WSL distro, named "WSL:<name>".
-- If your distro isn't literally "Ubuntu" (e.g. "Ubuntu-22.04"), run
-- `wsl -l -q` and change the name below to match.
config.default_domain = "WSL:Ubuntu"

-- Single-workspace usage — no tab bar clutter.
config.enable_tab_bar = false

-- Font. JetBrains Mono if installed, otherwise fall back to Consolas (ships
-- with Windows). Install JetBrains Mono for ligatures/nicer glyphs if you like.
config.font = wezterm.font_with_fallback({
  "JetBrains Mono",
  "Consolas",
})
config.font_size = 11.0

-- Don't prompt when closing the window.
config.window_close_confirmation = "NeverPrompt"

-- ----------------------------------------------------------------------------
-- Optional cosmetics — uncomment to taste.
-- ----------------------------------------------------------------------------
-- config.color_scheme = "Catppuccin Latte"   -- match the Neovim light theme
-- config.window_background_opacity = 0.95     -- slight transparency
-- config.macos_window_background_blur = 20    -- (macOS only) blur behind
-- config.window_padding = { left = 4, right = 4, top = 4, bottom = 4 }

return config
