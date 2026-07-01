-- ============================================================================
-- typst.lua — Typst language support
-- ============================================================================
-- Two pieces:
--   * tinymist — the Typst language server (completion, diagnostics, format).
--   * typst-preview.nvim — live preview that renders pages as INLINE IMAGES in
--     the terminal via the kitty graphics protocol. That protocol needs ioctl,
--     which only works when Neovim is a genuine Linux process — this is the
--     whole reason the stack runs inside WSL rather than native Windows Neovim.
--     (poppler-utils' pdfinfo is a runtime dependency; wsl/install.sh installs
--     it.)
-- ============================================================================

return {
  -- Register tinymist with LazyVim's nvim-lspconfig setup. LazyVim will also
  -- ask Mason to install it automatically for any server listed here.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tinymist = {
          single_file_support = true, -- notes/docs are usually standalone files
          settings = {
            formatterMode = "typstyle", -- format with typstyle via the LSP
          },
        },
      },
    },
  },

  -- Inline preview.
  {
    "al-kot/typst-preview.nvim",
    ft = "typst",
    opts = {
      preview = {
        max_width = 80,
        ppi = 144,      -- render density; higher = sharper but heavier
        position = "right",
      },
    },
    keys = {
      { "<leader>tp", function() require("typst-preview").start() end, ft = "typst", desc = "Start Typst Preview" },
      { "<leader>tq", function() require("typst-preview").stop() end, ft = "typst", desc = "Stop Typst Preview" },
    },
  },
}
