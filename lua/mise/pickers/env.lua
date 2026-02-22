--- Picker: Browse mise environment variables
--- Source: mise env -J (fetched on main thread before picker opens)
local M = {}

local pickers = require("mise.pickers")

---@param opts? table
function M.pick(opts)
  if not pickers.check_snacks() then return end
  local Snacks = require("snacks")
  local util = require("mise.util")
  local cfg = require("mise.config").get()
  opts = vim.tbl_deep_extend("force", cfg.pickers.env or {}, opts or {})

  local stdout, _, code = util.run({ "env", "-J" }, { cwd = util.cwd() })
  if code ~= 0 then
    util.notify("mise env failed", vim.log.levels.ERROR)
    return
  end
  local env, err = util.json_decode(stdout)
  if not env then
    util.notify("Failed to parse mise env: " .. (err or ""), vim.log.levels.ERROR)
    return
  end

  local items = {} ---@type snacks.picker.finder.Item[]
  local keys = vim.tbl_keys(env)
  table.sort(keys)
  for _, key in ipairs(keys) do
    local val = env[key]
    if type(val) ~= "string" then val = tostring(val) end
    local preview_lines
    if key == "PATH" then
      local paths = vim.split(val, ":", { plain = true })
      preview_lines = { key .. "=" }
      for _, p in ipairs(paths) do preview_lines[#preview_lines + 1] = "  " .. p end
    else
      preview_lines = { key .. "=" .. val }
    end
    items[#items + 1] = {
      text      = key .. "=" .. val,
      env_key   = key,
      env_value = val,
      preview   = pickers.make_preview(preview_lines, "bash"),
    }
  end

  ---@type snacks.picker.format
  local function format(item, _picker)
    local ret = {}
    ret[#ret + 1] = { item.env_key, "SnacksPickerLabel" }
    ret[#ret + 1] = { "=", "Comment", virtual = true }
    local display_val = item.env_value
    if #display_val > 80 then display_val = display_val:sub(1, 77) .. "..." end
    ret[#ret + 1] = { display_val, item.env_key == "PATH" and "SnacksPickerDir" or "Normal" }
    return ret
  end

  local actions = {
    yank_value = function(picker, item)
      vim.fn.setreg('"', item.env_value)
      vim.fn.setreg("+", item.env_value)
      util.notify("Yanked value of " .. item.env_key)
    end,
    yank_pair = function(picker, item)
      local pair = item.env_key .. "=" .. item.env_value
      vim.fn.setreg('"', pair)
      vim.fn.setreg("+", pair)
      util.notify("Yanked: " .. item.env_key .. "=...")
    end,
    edit_env_config = function(picker, item)
      picker:close()
      local found = vim.fs.find(
        { "mise.toml", ".mise.toml", "mise.local.toml" },
        { upward = true, path = vim.fn.getcwd() }
      )
      if found[1] then
        vim.cmd("edit " .. vim.fn.fnameescape(found[1]))
        vim.fn.search("\\[env\\]", "w")
        vim.fn.search(vim.fn.escape(item.env_key, "[]().*+?^${}|\\"), "w")
      else
        util.notify("No mise.toml found", vim.log.levels.WARN)
      end
    end,
  }

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title   = "Mise Environment",
    finder  = items,
    format  = format,
    preview = "preview",
    matcher = { fuzzy = true, smartcase = true },
    actions = actions,
    win = { input = { keys = {
      ["<CR>"]  = { "yank_value",      mode = { "n", "i" }, desc = "Yank value" },
      ["<C-y>"] = { "yank_pair",       mode = { "n", "i" }, desc = "Yank KEY=VALUE" },
      ["<C-e>"] = { "edit_env_config", mode = { "n", "i" }, desc = "Edit in mise.toml" },
    }}},
  }, opts))
end

return M
