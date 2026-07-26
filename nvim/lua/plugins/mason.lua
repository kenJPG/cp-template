-- Pinned editor tools are installed synchronously by config.bootstrap. Keep
-- Mason's normal asynchronous installer disabled so it cannot race that path.
return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = {}
    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = {}
    end,
  },
}
