-- ============================================================================
-- cpp.lua — C++ language support (competitive programming)
-- ============================================================================
-- Just clangd through LazyVim's nvim-lspconfig, with defaults. This is for
-- single-file contest solutions, not large CMake projects, so there's nothing
-- special to configure — clangd's defaults give completion and diagnostics out
-- of the box. install.ps1 installs clangd via winget directly (LLVM.clangd),
-- so it's ready immediately rather than waiting on Mason's lazy install.
--
-- Note: clangd (LSP) and g++ (the actual compiler, from WinLibs) are
-- deliberately different toolchains here — see install.ps1 for why real GCC
-- matters for competitive programming (<bits/stdc++.h>, #pragma GCC ...).
-- clangd's diagnostics are close enough to be useful despite that mismatch.
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
