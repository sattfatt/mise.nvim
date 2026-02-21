-- mise-nvim: Neovim plugin for mise (https://mise.jdx.dev)
-- This file is auto-loaded by Neovim's plugin/ directory loading.
-- It is intentionally minimal — all setup is deferred to require("mise").setup()

if vim.fn.has("nvim-0.9.0") ~= 1 then
  vim.notify("[mise-nvim] Neovim >= 0.9.0 is required", vim.log.levels.ERROR)
  return
end

-- Prevent double-loading
if vim.g.mise_nvim_loaded then
  return
end
vim.g.mise_nvim_loaded = true
