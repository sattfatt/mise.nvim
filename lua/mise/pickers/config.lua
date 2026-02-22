--- Picker: Browse mise config files
--- Source: mise config ls (fetched on main thread before picker opens)
local M = {}

local pickers = require("mise.pickers")

---@param opts? table
function M.pick(opts)
  if not pickers.check_snacks() then return end
  local Snacks = require("snacks")
  local util = require("mise.util")
  local cfg = require("mise.config").get()
  opts = vim.tbl_deep_extend("force", cfg.pickers.config or {}, opts or {})

  local stdout, _, code = util.run({ "config", "ls" }, { cwd = util.cwd() })
  if code ~= 0 then
    util.notify("mise config ls failed", vim.log.levels.ERROR)
    return
  end

  local items = {} ---@type snacks.picker.finder.Item[]
  for _, line in ipairs(vim.split(stdout, "\n")) do
    line = vim.trim(line)
    if line ~= "" then
      local path, tools_str = line:match("^(%S+)%s+(.+)$")
      if not path then path = line end
      local expanded = vim.fn.expand(path)
      local tools = {}
      if tools_str then
        for _, t in ipairs(vim.split(tools_str, ",")) do
          t = vim.trim(t)
          if t ~= "" then tools[#tools + 1] = t end
        end
      end
      items[#items + 1] = {
        text        = expanded .. " " .. table.concat(tools, " "),
        file        = expanded,
        config_path = expanded,
        tools       = tools,
        exists      = vim.fn.filereadable(expanded) == 1,
        preview     = "file",
      }
    end
  end

  ---@type snacks.picker.format
  local function format(item, _picker)
    local ret = {}
    local icon, icon_hl
    if item.exists then
      icon, icon_hl = " ", "SnacksPickerIcon"
    else
      icon, icon_hl = " ", "DiagnosticError"
    end
    ret[#ret + 1] = { icon .. " ", icon_hl, virtual = true }
    local short = vim.fn.fnamemodify(item.config_path, ":~")
    local dir = vim.fn.fnamemodify(short, ":h")
    local base = vim.fn.fnamemodify(short, ":t")
    if dir and dir ~= "." and dir ~= short then
      ret[#ret + 1] = { dir .. "/", "SnacksPickerDir" }
      ret[#ret + 1] = { base, "SnacksPickerFile", field = "file" }
    else
      ret[#ret + 1] = { short, "SnacksPickerFile", field = "file" }
    end
    if #item.tools > 0 then
      ret[#ret + 1] = { "  " .. table.concat(item.tools, ", "), "SnacksPickerComment" }
    end
    return ret
  end

  local actions = {
    mise_trust = function(picker, item)
      pickers.close_and_run(picker, { "trust", item.config_path }, "Trusted: " .. item.config_path, "Trust failed")
    end,
    mise_untrust = function(picker, item)
      pickers.close_and_run(picker, { "trust", "--untrust", item.config_path }, "Revoked trust: " .. item.config_path, "Untrust failed")
    end,
  }

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title   = "Mise Config Files",
    finder  = function() return items end,
    format  = format,
    preview = "preview",
    matcher = { fuzzy = true, smartcase = true },
    actions = actions,
    win = { input = {
      footer = pickers.make_footer({
        ["<C-t>"] = { desc = "Trust" },
        ["<C-u>"] = { desc = "Untrust" },
      }),
      footer_pos = "left",
      keys = {
        ["<C-t>"] = { "mise_trust",   mode = { "n", "i" }, desc = "Trust config" },
        ["<C-u>"] = { "mise_untrust", mode = { "n", "i" }, desc = "Revoke trust" },
      },
    }},
  }, opts))
end

return M
