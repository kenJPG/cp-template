-- ============================================================================
-- completion.lua — tone down blink.cmp's ghost-text preview
-- ============================================================================
-- LazyVim's default completion engine (blink.cmp) shows an inline "ghost text"
-- preview of the top fuzzy match as you type, in a muted color. It's genuinely
-- useful for code, but noisy for prose (Typst math notes) — it renders
-- unrelated fuzzy matches right after your cursor, which looks like garbage
-- text (e.g. random word fragments) and is easy to mistake for something you
-- actually typed.
--
-- Gotcha this caused: when the ghost-text/completion popup is visible, the
-- FIRST <Esc> only dismisses it — you're still in Insert mode. So `<Esc>A`
-- right after doesn't run the Normal-mode "append at end of line" command, it
-- just inserts a literal "A". A second <Esc> is needed to truly leave Insert
-- mode when that popup is up. Disabling ghost_text removes the main source of
-- that confusion; the real completion menu (<C-space> / accepted with <Tab> or
-- <CR>) is unaffected.
-- ============================================================================

return {
  {
    "saghen/blink.cmp",
    opts = {
      completion = {
        ghost_text = { enabled = false },
      },
    },
  },
}
