local function notify(msg, level)
  vim.notify(msg, level, { title = "Typst" })
end

local function export_pdf()
  local source_path = vim.api.nvim_buf_get_name(0)
  if source_path == "" or vim.bo.buftype ~= "" then
    notify("Open a saved Typst file before exporting.", vim.log.levels.ERROR)
    return
  end

  local wrote, write_error = pcall(vim.cmd, "silent write")
  if not wrote then
    notify("Could not save the Typst source: " .. tostring(write_error), vim.log.levels.ERROR)
    return
  end

  local pdf_path = vim.fn.fnamemodify(source_path, ":r") .. ".pdf"
  local cwd = vim.fn.fnamemodify(source_path, ":h")

  notify("Exporting PDF...", vim.log.levels.INFO)

  local started, spawn_error = pcall(vim.system, { "typst", "compile", source_path, pdf_path }, { text = true, cwd = cwd }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        notify((res.stderr ~= "" and res.stderr or res.stdout) or "typst compile failed", vim.log.levels.ERROR)
        return
      end

      if not vim.uv.fs_stat(pdf_path) then
        notify("Typst reported success, but no PDF was written: " .. pdf_path, vim.log.levels.ERROR)
        return
      end

      local ok, opened = pcall(vim.ui.open, pdf_path)
      if not ok or not opened then
        notify("Wrote PDF, but could not open it automatically: " .. pdf_path, vim.log.levels.ERROR)
        return
      end

      notify("Wrote and opened " .. pdf_path, vim.log.levels.INFO)
    end)
  end)

  if not started then
    notify("Failed to start Typst: " .. tostring(spawn_error), vim.log.levels.ERROR)
  end
end

return {
  -- Register Tinymist with LazyVim's nvim-lspconfig setup. The installer owns
  -- this binary system-wide, so Mason is explicitly disabled for the server.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tinymist = {
          mason = false,
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
      dependencies_bin = {
        tinymist = "tinymist", -- use the winget-managed binary already on PATH
      },
    },
    keys = {
      { "<leader>tp", "<cmd>TypstPreviewToggle<CR>", ft = "typst", desc = "Typst: toggle preview" },
      { "<leader>tq", "<cmd>TypstPreviewStop<CR>", ft = "typst", desc = "Typst: stop preview" },
      {
        "<leader>te",
        export_pdf,
        ft = "typst",
        desc = "Typst: export to PDF",
      },
    },
  },
}
