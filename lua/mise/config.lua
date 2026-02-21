---@class MiseTerminalConfig
---@field split "horizontal"|"vertical"|"float" Split direction for task terminal
---@field height number Lines for horizontal split
---@field width number Cols for vertical split

---@class MiseAutocmdsConfig
---@field watch_config boolean Auto-refresh when mise.toml changes
---@field notify_on_dir_change boolean Notify when active tool versions change on DirChanged

---@class MiseStatuslineConfig
---@field icon string Icon prefix for tool names
---@field tools string[] Tools to show (empty = all active)

---@class MisePickersConfig
---@field tools? table Extra opts passed to tools picker
---@field tasks? table Extra opts passed to tasks picker
---@field registry? table Extra opts passed to registry picker
---@field versions? table Extra opts passed to versions picker
---@field plugins? table Extra opts passed to plugins picker
---@field config? table Extra opts passed to config picker
---@field env? table Extra opts passed to env picker
---@field outdated? table Extra opts passed to outdated picker

---@class MiseNotifyConfig
---@field level number vim.log.levels.* for success notifications

---@class MiseConfig
---@field mise_path string Path to mise binary
---@field cwd "cwd"|"root" Where to run mise commands
---@field terminal MiseTerminalConfig
---@field autocmds MiseAutocmdsConfig
---@field statusline MiseStatuslineConfig
---@field pickers MisePickersConfig
---@field notify MiseNotifyConfig

local M = {}

---@type MiseConfig
local defaults = {
  mise_path = "mise",
  cwd = "cwd",
  terminal = {
    split = "horizontal",
    height = 15,
    width = 80,
  },
  autocmds = {
    watch_config = true,
    notify_on_dir_change = true,
  },
  statusline = {
    icon = " ",
    tools = {},
  },
  pickers = {
    tools = {},
    tasks = {},
    registry = {},
    versions = {},
    plugins = {},
    config = {},
    env = {},
    outdated = {},
  },
  notify = {
    level = vim.log.levels.INFO,
  },
}

---@type MiseConfig
local _config = vim.deepcopy(defaults)

---@param opts? MiseConfig
function M.setup(opts)
  _config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

---@return MiseConfig
function M.get()
  return _config
end

return M
