-- ============================================================================
-- colorscheme.lua — light theme
-- ============================================================================
-- I work in a light theme. Default is catppuccin "latte". tokyonight is also
-- installed with the "day" style as a one-line alternative in case latte's
-- cream/warm background gets tiring and I want a starker white.
--
-- To switch, change the `colorscheme` value in the LazyVim opts block below:
--     colorscheme = "catppuccin"       -- latte (default, warm)
--     colorscheme = "tokyonight-day"   -- starker white alternative
-- ============================================================================

return {
  -- Catppuccin, pinned to the light "latte" flavour.
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "latte",
      background = { light = "latte", dark = "latte" },
    },
  },

  -- Tokyonight, "day" style — kept around as an easy alternative (see header).
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "day",
    },
  },

  -- Tell LazyVim which colorscheme to actually apply.
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
