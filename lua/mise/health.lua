local M = {}

function M.check()
  local h = vim.health

  h.start("mise-nvim")

  -- 1. Neovim version
  if vim.fn.has("nvim-0.9.0") == 1 then
    h.ok("Neovim >= 0.9.0")
  else
    h.error("Neovim >= 0.9.0 is required")
    return
  end

  local cfg = require("mise.config").get()
  local util = require("mise.util")

  -- 2. mise binary
  local mise_bin = cfg.mise_path
  if vim.fn.executable(mise_bin) == 1 then
    local stdout, _, _ = util.run({ "--version" })
    h.ok("mise found: " .. vim.trim(stdout))
  else
    h.error("mise binary not found: '" .. mise_bin .. "'. Install mise from https://mise.jdx.dev or set config.mise_path")
    return
  end

  -- 3. mise doctor
  local doctor_out, _, doctor_code = util.run({ "doctor" })
  if doctor_code == 0 then
    h.ok("mise doctor passed")
    -- Check activation status
    for _, line in ipairs(vim.split(doctor_out, "\n")) do
      if line:find("activated:") then
        local status = line:match("activated:%s*(%S+)")
        if status and status ~= "true" and status ~= "yes" then
          h.warn("mise is not activated in the current shell. Some features may not work correctly.")
        end
      end
      if line:find("^%[WARN%]") or line:find("^WARN:") then
        h.warn(vim.trim(line))
      end
    end
  else
    h.warn("mise doctor reported issues:")
    for _, line in ipairs(vim.split(doctor_out, "\n")) do
      line = vim.trim(line)
      if line ~= "" then
        h.info("  " .. line)
      end
    end
  end

  -- 4. snacks.nvim
  local has_snacks = util.has_snacks()
  if has_snacks then
    h.ok("snacks.nvim found")
    local ok, snacks = pcall(require, "snacks")
    if ok and snacks and snacks.config then
      -- Check if picker is configured
      local picker_ok = pcall(function()
        local _ = require("snacks.picker")
      end)
      if picker_ok then
        h.ok("snacks.nvim picker available")
      else
        h.warn("snacks.nvim picker not available. Add `picker = {}` to your snacks.nvim opts.")
      end
    end
  else
    h.warn("snacks.nvim not found. Pickers will be unavailable. Install folke/snacks.nvim for full functionality.")
  end

  -- 5. vim.system() availability
  if vim.fn.has("nvim-0.10.0") == 1 then
    h.ok("vim.system() available (Neovim >= 0.10) — async commands fully supported")
  else
    h.warn("Neovim < 0.10: vim.system() not available, falling back to vim.fn.system() (blocking). Upgrade for best experience.")
  end

  -- 6. Configuration summary
  h.info("Configuration:")
  h.info("  mise_path: " .. cfg.mise_path)
  h.info("  cwd mode: " .. cfg.cwd)
  h.info("  watch_config: " .. tostring(cfg.autocmds.watch_config))
  h.info("  notify_on_dir_change: " .. tostring(cfg.autocmds.notify_on_dir_change))
end

return M
