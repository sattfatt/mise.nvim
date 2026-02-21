--- Picker: Browse mise plugins (installed and remote)
--- Sources: mise plugins ls (installed), mise plugins ls-remote (all available)
local M = {}

local pickers = require("mise.pickers")

--- Internal: open picker in a specific mode.
---@param mode "installed"|"remote"
---@param caller_opts? table
local function _pick(mode, caller_opts)
  if not pickers.check_snacks() then
    return
  end
  local Snacks = require("snacks")
  local util = require("mise.util")

  local args = mode == "remote"
    and { "plugins", "ls-remote" }
    or  { "plugins", "ls" }

  ---@type snacks.picker.finder
  local function finder(fopts, ctx)
    return require("snacks.picker.source.proc").proc(
      ctx:opts({
        cmd  = util.mise_bin(),
        args = args,
        transform = function(item)
          local text = vim.trim(item.text)
          if text == "" then
            return false
          end

          -- "ls-remote" marks installed plugins with a trailing " *" or leading "*"
          -- "ls" shows plain names (these are all installed)
          local installed = false
          local name = text

          if mode == "remote" then
            -- Some versions suffix with " *" for installed
            if text:match("%s%*$") then
              installed = true
              name = vim.trim(text:gsub("%s%*$", ""))
            elseif text:match("^%*%s") then
              installed = true
              name = vim.trim(text:gsub("^%*%s", ""))
            end
          else
            installed = true
          end

          item.plugin_name = name
          item.installed   = installed
          item.mode        = mode
          item.text        = name
          item.preview     = pickers.make_preview({
            "plugin: " .. name,
            "installed: " .. tostring(installed),
            "source: mise plugins ls" .. (mode == "remote" and "-remote" or ""),
          }, "yaml")
        end,
      }),
      ctx
    )
  end

  ---@type snacks.picker.format
  local function format(item, _picker)
    local ret = {} ---@type snacks.picker.Highlight[]

    -- Installation status icon
    if item.installed then
      ret[#ret + 1] = { "✓ ", "DiagnosticOk", virtual = true }
    elseif mode == "remote" then
      ret[#ret + 1] = { "  ", "Normal", virtual = true }
    end

    -- Plugin name
    ret[#ret + 1] = { item.plugin_name, item.installed and "SnacksPickerLabel" or "Normal" }

    return ret
  end

  local actions = {
    -- Install the plugin
    plugin_install = function(picker, item)
      pickers.close_and_run(
        picker,
        { "plugins", "install", item.plugin_name },
        "Installed plugin: " .. item.plugin_name,
        "Plugin install failed"
      )
    end,
    -- Uninstall with confirmation
    plugin_uninstall = function(picker, item)
      if not item.installed then
        util.notify("Plugin '" .. item.plugin_name .. "' is not installed", vim.log.levels.WARN)
        return
      end
      pickers.confirm("Uninstall plugin '" .. item.plugin_name .. "'?", function()
        pickers.close_and_run(
          picker,
          { "plugins", "uninstall", item.plugin_name },
          "Uninstalled plugin: " .. item.plugin_name,
          "Plugin uninstall failed"
        )
      end)
    end,
    -- Update an installed plugin
    plugin_update = function(picker, item)
      if not item.installed then
        util.notify("Plugin '" .. item.plugin_name .. "' is not installed", vim.log.levels.WARN)
        return
      end
      pickers.close_and_run(
        picker,
        { "plugins", "update", item.plugin_name },
        "Updated plugin: " .. item.plugin_name,
        "Plugin update failed"
      )
    end,
    -- Toggle between installed and remote modes
    toggle_remote = function(picker, _item)
      picker:close()
      local next_mode = mode == "remote" and "installed" or "remote"
      _pick(next_mode, caller_opts)
    end,
    -- Yank plugin name
    yank_name = function(picker, item)
      vim.fn.setreg('"', item.plugin_name)
      vim.fn.setreg("+", item.plugin_name)
      util.notify("Yanked: " .. item.plugin_name)
    end,
  }

  local title = mode == "remote" and "Mise Plugins (Remote)" or "Mise Plugins (Installed)"

  -- <CR> behavior differs by mode
  local confirm_action = mode == "remote" and "plugin_install" or "plugin_update"

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title   = title,
    finder  = finder,
    format  = format,
    preview = "preview",
    matcher = {
      fuzzy     = true,
      smartcase = true,
    },
    actions = actions,
    win = {
      input = {
        keys = {
          ["<CR>"]  = { confirm_action,    mode = { "n", "i" }, desc = mode == "remote" and "Install" or "Update" },
          ["<C-i>"] = { "plugin_install",  mode = { "n", "i" }, desc = "Install plugin" },
          ["<C-x>"] = { "plugin_uninstall",mode = { "n", "i" }, desc = "Uninstall plugin" },
          ["<C-u>"] = { "plugin_update",   mode = { "n", "i" }, desc = "Update plugin" },
          ["<C-t>"] = { "toggle_remote",   mode = { "n", "i" }, desc = mode == "remote" and "Show installed" or "Show remote" },
          ["<C-y>"] = { "yank_name",       mode = { "n", "i" }, desc = "Yank plugin name" },
        },
      },
    },
  }, caller_opts or {}))
end

--- Open the plugins picker (defaults to installed mode).
---@param opts? {mode?: "installed"|"remote"}
function M.pick(opts)
  opts = opts or {}
  local mode = opts.mode or "installed"
  _pick(mode, opts)
end

return M
