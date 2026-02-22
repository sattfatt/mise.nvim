---@class mise
local M = {}

-- Version cache: invalidated when mise.toml is saved
local _cache = {} ---@type table<string, any>

--- Setup the plugin. Call once from your Neovim config.
---@param opts? MiseConfig
function M.setup(opts)
  require("mise.config").setup(opts)
  -- Resolve and cache the mise binary path on the main thread now,
  -- so util.mise_bin() never needs to call Vimscript from a fast context.
  require("mise.util").mise_bin()
  require("mise.commands").setup()
  require("mise.autocmd").setup()
end

--- Get the current version of a specific tool.
--- Synchronous and cached — safe to call from statusline providers.
--- Returns nil if the tool is not active or mise is not available.
---@param tool string e.g. "node", "python"
---@return string|nil
function M.get_tool_version(tool)
  if _cache[tool] ~= nil then
    return _cache[tool] or nil
  end
  local util = require("mise.util")
  if not util.check_mise() then
    return nil
  end
  local stdout, _, code = util.run({ "current", tool })
  if code ~= 0 then
    _cache[tool] = false -- cache miss
    return nil
  end
  local ver = vim.trim(stdout)
  if ver == "" then
    _cache[tool] = false
    return nil
  end
  _cache[tool] = ver
  return ver
end

--- Get all currently active tools.
--- Synchronous and cached — safe to call from statusline providers.
---@return {name: string, version: string}[]
function M.get_active_tools()
  if _cache.__all_active then
    return _cache.__all_active
  end
  local util = require("mise.util")
  if not util.check_mise() then
    return {}
  end
  local stdout, _, code = util.run({ "current" })
  if code ~= 0 then
    return {}
  end
  local result = {} ---@type {name: string, version: string}[]
  for _, line in ipairs(vim.split(vim.trim(stdout), "\n")) do
    line = vim.trim(line)
    if line ~= "" then
      local tool, ver = line:match("^(%S+)%s+(%S+)$")
      if tool and ver then
        result[#result + 1] = { name = tool, version = ver }
      end
    end
  end
  _cache.__all_active = result
  return result
end

--- Invalidate the internal version cache.
--- Called automatically when mise.toml is saved.
function M.invalidate_cache()
  _cache = {}
  -- Also clear the resolved binary path in case mise_path config changed
  require("mise.util")._mise_bin = nil
end

--- Return tool names matching arglead, for command completion.
--- Searches the mise registry (may be slow on first call).
---@param arglead string
---@return string[]
function M.complete_tools(arglead)
  local util = require("mise.util")
  local stdout, _, code = util.run({ "registry" })
  if code ~= 0 then
    return {}
  end
  local matches = {} ---@type string[]
  for _, line in ipairs(vim.split(stdout, "\n")) do
    local name = line:match("^(%S+)")
    if name and (arglead == "" or name:find(arglead, 1, true) == 1) then
      matches[#matches + 1] = name
    end
  end
  return matches
end

--- Return installed tool@version specs matching arglead.
---@param arglead string
---@return string[]
function M.complete_installed_tools(arglead)
  local util = require("mise.util")
  local stdout, _, code = util.run({ "ls", "--json" })
  if code ~= 0 then
    return {}
  end
  local data, _ = util.json_decode(stdout)
  if not data then
    return {}
  end
  local matches = {} ---@type string[]
  for name, versions in pairs(data) do
    if arglead == "" or name:find(arglead, 1, true) == 1 then
      matches[#matches + 1] = name
    end
    -- Also offer tool@version completions
    if type(versions) == "table" then
      for _, v in ipairs(versions) do
        if v.version then
          local spec = name .. "@" .. v.version
          if arglead == "" or spec:find(arglead, 1, true) == 1 then
            matches[#matches + 1] = spec
          end
        end
      end
    end
  end
  table.sort(matches)
  return matches
end

--- Return task names matching arglead.
---@param arglead string
---@return string[]
function M.complete_tasks(arglead)
  local util = require("mise.util")
  local stdout, _, code = util.run({ "tasks", "ls", "--json" })
  if code ~= 0 then
    return {}
  end
  local tasks, _ = util.json_decode(stdout)
  if not tasks or type(tasks) ~= "table" then
    return {}
  end
  local matches = {} ---@type string[]
  for _, task in ipairs(tasks) do
    if task.name and (arglead == "" or task.name:find(arglead, 1, true) == 1) then
      matches[#matches + 1] = task.name
    end
  end
  return matches
end

return M
