-- Minimal Neovim config for running mise-nvim tests.
-- Adds the plugin itself to runtimepath; plenary must be on rtp too.

-- Add the plugin root to runtimepath
vim.opt.runtimepath:prepend(vim.fn.getcwd())

-- Add plenary (required for the test runner)
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.runtimepath:prepend(plenary_path)
else
  -- Fallback: try common locations
  local fallbacks = {
    vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"),
    vim.fn.expand("~/.local/share/nvim/site/pack/packer/start/plenary.nvim"),
  }
  for _, p in ipairs(fallbacks) do
    if vim.fn.isdirectory(p) == 1 then
      vim.opt.runtimepath:prepend(p)
      break
    end
  end
end

-- Add snacks.nvim if available (some picker tests need it)
local snacks_path = vim.fn.stdpath("data") .. "/lazy/snacks.nvim"
if vim.fn.isdirectory(snacks_path) == 1 then
  vim.opt.runtimepath:prepend(snacks_path)
end

-- Disable swap files for tests
vim.o.swapfile = false

-- Load plugin (trigger plugin/mise.lua)
vim.cmd("runtime plugin/mise.lua")
