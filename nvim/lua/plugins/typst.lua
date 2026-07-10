-- ============================================================================
-- typst.lua — Typst language support
-- ============================================================================
-- Three pieces:
--   * tinymist — the Typst language server (completion, diagnostics, format).
--   * typst-preview.nvim (chomosuke fork) — live preview rendered as an SVG
--     page in a normal browser tab, over a local HTTP+WebSocket server. This
--     is deliberately NOT inline-terminal image rendering (kitty graphics
--     protocol): that route needs the terminal to report per-cell pixel size
--     accurately, which is unreliable in practice and was a whole saga on its
--     own. A browser tab sidesteps all of that — it's just an HTTP server and
--     your normal browser, and it's why this whole setup can run as plain
--     native Windows Neovim with no Linux VM underneath it at all.
--   * <leader>te — export the current file straight to PDF via `typst compile`
--     and open it, for when you want an actual document instead of a preview.
-- ============================================================================

return {
  -- Register tinymist with LazyVim's nvim-lspconfig setup. LazyVim will also
  -- ask Mason to install it automatically for any server listed here (though
  -- install.ps1 already puts a system-wide tinymist on PATH via winget).
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

  -- Browser-based live preview.
  {
    "chomosuke/typst-preview.nvim",
    ft = "typst",
    version = "*", -- pin to tagged releases; avoid chasing main
    opts = {
      -- open_cmd left unset: the plugin already knows how to open the
      -- system's default browser per-OS. No override needed here.
      follow_cursor = true, -- preview scrolls to match cursor position
      -- dependencies_bin left unset on purpose: the plugin downloads its own
      -- pinned tinymist + websocat into stdpath('data')/typst-preview on
      -- first use, decoupled from the tinymist install.ps1 puts on PATH for
      -- the LSP above. First `<leader>tp` run will pause briefly to fetch
      -- them (needs `curl`, which Windows 10/11 ships built in).
    },
    keys = {
      { "<leader>tp", "<cmd>TypstPreview<CR>", ft = "typst", desc = "Start Typst Preview (browser)" },
      { "<leader>tq", "<cmd>TypstPreviewStop<CR>", ft = "typst", desc = "Stop Typst Preview" },
      {
        "<leader>te",
        function()
          vim.cmd("silent! write")
          local src = vim.fn.expand("%:p")
          local pdf = vim.fn.expand("%:p:r") .. ".pdf"
          vim.notify("Exporting to PDF...", vim.log.levels.INFO, { title = "typst export" })
          vim.system({ "typst", "compile", src, pdf }, { text = true }, function(res)
            vim.schedule(function()
              if res.code ~= 0 then
                vim.notify(
                  (res.stderr ~= "" and res.stderr or res.stdout) or "typst compile failed",
                  vim.log.levels.ERROR,
                  { title = "typst export" }
                )
                return
              end
              vim.notify("Wrote " .. pdf, vim.log.levels.INFO, { title = "typst export" })
              vim.ui.open(pdf) -- opens with whatever's registered for .pdf on Windows
            end)
          end)
        end,
        ft = "typst",
        desc = "Typst: export to PDF",
      },
    },
  },
}
