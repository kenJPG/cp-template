-- ============================================================================
-- editor.lua — editor-behaviour overrides
-- ============================================================================
-- LazyVim enables mini.pairs out of the box. We use our own smart auto-pair
-- engine instead (lua/config/autopairs.lua, installed from keymaps.lua), so we
-- turn mini.pairs off here to avoid two systems fighting over ( [ { etc.
-- ============================================================================

return {
  { "echasnovski/mini.pairs", enabled = false },
}
