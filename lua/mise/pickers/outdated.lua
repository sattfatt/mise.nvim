--- Picker: Show outdated mise tools
--- Source: mise outdated --json (fetched on main thread before picker opens)
local M = {}

local pickers = require("mise.pickers")

---@param opts? table
function M.pick(opts)
  if not pickers.check_snacks() then return end
  local Snacks = require("snacks")
  local util = require("mise.util")
  local cfg = require("mise.config").get()
  opts = vim.tbl_deep_extend("force", cfg.pickers.outdated or {}, opts or {})

  local stdout, _, code = util.run({ "outdated", "--json" }, { cwd = util.cwd() })
  if code ~= 0 then
    util.notify("mise outdated failed", vim.log.levels.ERROR)
    return
  end
  local outdated, err = util.json_decode(stdout)
  if not outdated then
    util.notify("Failed to parse mise outdated: " .. (err or ""), vim.log.levels.ERROR)
    return
  end
  if vim.tbl_isempty(outdated) then
    util.notify("All tools are up to date!")
    return
  end

  local items = {} ---@type snacks.picker.finder.Item[]
  local names = vim.tbl_keys(outdated)
  table.sort(names)
  for _, name in ipairs(names) do
    local info = outdated[name]
    local source_path = info.source and info.source.path or nil
    local bump = info.bump
    items[#items + 1] = {
      text        = name .. " " .. (info.current or "") .. " " .. (info.latest or ""),
      tool        = name,
      current     = info.current or "",
      latest      = info.latest or "",
      bump        = bump,
      requested   = info.requested or "",
      source_path = source_path,
      file        = source_path,
      preview     = pickers.make_preview({
        "tool: " .. name,
        "current: " .. (info.current or ""),
        "latest: " .. (info.latest or ""),
        "requested: " .. (info.requested or ""),
        "bump_type: " .. (bump or "unknown"),
        "source: " .. (source_path or ""),
      }, "yaml"),
    }
  end

  ---@type snacks.picker.format
  local function format(item, _picker)
    local ret = {}
    ret[#ret + 1] = { item.tool, "SnacksPickerLabel" }
    ret[#ret + 1] = { "  ", "Normal", virtual = true }
    ret[#ret + 1] = { item.current, "SnacksPickerComment" }
    ret[#ret + 1] = { " → ", "Comment", virtual = true }
    local bump_hl = ({ major = "DiagnosticError", minor = "DiagnosticWarn", patch = "DiagnosticHint" })[item.bump] or "DiagnosticInfo"
    ret[#ret + 1] = { item.latest, bump_hl }
    if item.bump then
      ret[#ret + 1] = { "  [" .. item.bump .. "]", "SnacksPickerComment", virtual = true }
    end
    return ret
  end

  local actions = {
    mise_upgrade = function(picker, item)
      pickers.close_and_run(picker, { "upgrade", item.tool }, "Upgraded " .. item.tool, "Upgrade failed")
    end,
    upgrade_all = function(picker, _item)
      pickers.confirm("Upgrade all outdated tools?", function()
        pickers.close_and_run(picker, { "upgrade" }, "Upgraded all tools", "Upgrade all failed")
      end)
    end,
    edit_source = function(picker, item)
      picker:close()
      if item.file then vim.cmd("edit " .. vim.fn.fnameescape(item.file)) end
    end,
    yank_cmd = function(picker, item)
      local cmd = "mise upgrade " .. item.tool
      vim.fn.setreg('"', cmd)
      vim.fn.setreg("+", cmd)
      util.notify("Yanked: " .. cmd)
    end,
  }

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title   = "Mise Outdated Tools",
    finder  = function() return items end,
    format  = format,
    preview = "preview",
    matcher = { fuzzy = true, smartcase = true },
    actions = actions,
    win = { input = {
      footer = pickers.make_footer({
        ["<CR>"]  = { desc = "Upgrade" },
        ["<C-a>"] = { desc = "Upgrade all" },
        ["<C-e>"] = { desc = "Edit" },
        ["<C-y>"] = { desc = "Yank cmd" },
      }),
      footer_pos = "left",
      keys = {
        ["<CR>"]  = { "mise_upgrade", mode = { "n", "i" }, desc = "Upgrade selected tool" },
        ["<C-a>"] = { "upgrade_all",  mode = { "n", "i" }, desc = "Upgrade all tools" },
        ["<C-e>"] = { "edit_source",  mode = { "n", "i" }, desc = "Edit source config" },
        ["<C-y>"] = { "yank_cmd",     mode = { "n", "i" }, desc = "Yank upgrade command" },
      },
    }},
  }, opts))
end

return M
