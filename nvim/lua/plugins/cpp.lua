-- ============================================================================
-- cpp.lua — C++ language support (competitive programming)
-- ============================================================================
-- Just clangd through LazyVim's nvim-lspconfig, with defaults. This is for
-- single-file contest solutions, not large CMake projects, so there's nothing
-- special to configure — clangd's defaults give completion and diagnostics out
-- of the box. LazyVim/Mason installs clangd automatically for any server listed
-- here; wsl/install.sh also apt-installs it so the system compiler toolchain and
-- clangd match.
-- ============================================================================

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {},
      },
    },
  },
}
