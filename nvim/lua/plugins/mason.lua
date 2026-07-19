-- All required command-line tools are installed by install.ps1. Keep Mason's
-- UI available, but do not race the fail-closed bootstrap with duplicate installs.
return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = {}
    end,
  },
}
