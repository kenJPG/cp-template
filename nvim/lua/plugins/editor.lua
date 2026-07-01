-- ============================================================================
-- editor.lua — editor-behaviour overrides
-- ============================================================================
-- LazyVim enables mini.pairs out of the box. We use our own smart auto-pair
-- engine instead (lua/config/autopairs.lua, installed from keymaps.lua), so we
-- turn mini.pairs off here to avoid two systems fighting over ( [ { etc.
-- ============================================================================

return {
  -- mini.pairs moved from echasnovski/* to the nvim-mini org; lazy.nvim
  -- resolves plugins by short name ("mini.pairs") so the disable applies
  -- either way, but point at the new URL to avoid relying on the old org.
  { "nvim-mini/mini.pairs", enabled = false },
}
