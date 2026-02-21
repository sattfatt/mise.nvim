local M = {}

function M.setup()
  local cfg = require("mise.config").get()

  if not cfg.autocmds.watch_config and not cfg.autocmds.notify_on_dir_change then
    return
  end

  local group = vim.api.nvim_create_augroup("mise_nvim", { clear = true })

  -- Watch mise config files for changes
  if cfg.autocmds.watch_config then
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = group,
      pattern = {
        "mise.toml",
        ".mise.toml",
        "mise.local.toml",
        "*/mise/config.toml",
        "*/.config/mise/config.toml",
        "*/.config/mise.toml",
      },
      callback = function(ev)
        -- Invalidate the version cache
        require("mise").invalidate_cache()
        -- Emit a User event so other plugins/statuslines can react
        vim.api.nvim_exec_autocmds("User", {
          pattern = "MiseConfigChanged",
          data = { file = ev.file },
        })
      end,
    })
  end

  -- Notify when entering a directory with different active tool versions
  if cfg.autocmds.notify_on_dir_change then
    local prev_tools = {} ---@type table<string, string>

    vim.api.nvim_create_autocmd("DirChanged", {
      group = group,
      pattern = "*",
      callback = function()
        local util = require("mise.util")
        if not util.check_mise() then
          return
        end
        util.run_async({ "current" }, function(stdout, _, code)
          if code ~= 0 then
            return
          end
          -- Parse "TOOL VERSION\n..." lines
          local current = {} ---@type table<string, string>
          for _, line in ipairs(vim.split(vim.trim(stdout), "\n")) do
            line = vim.trim(line)
            if line ~= "" then
              local tool, ver = line:match("^(%S+)%s+(%S+)$")
              if tool and ver then
                current[tool] = ver
              end
            end
          end
          -- Compare with previous directory's tools
          local changes = {} ---@type string[]
          for tool, ver in pairs(current) do
            if prev_tools[tool] ~= ver then
              if prev_tools[tool] then
                changes[#changes + 1] = tool .. "@" .. ver .. " (was " .. prev_tools[tool] .. ")"
              else
                changes[#changes + 1] = tool .. "@" .. ver .. " (new)"
              end
            end
          end
          -- Also note removed tools
          for tool in pairs(prev_tools) do
            if not current[tool] then
              changes[#changes + 1] = tool .. " (removed)"
            end
          end
          prev_tools = current
          if #changes > 0 then
            util.notify("Active tools: " .. table.concat(changes, ", "))
          end
        end)
      end,
    })
  end
end

return M
