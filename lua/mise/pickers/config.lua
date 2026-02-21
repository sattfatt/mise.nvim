--- Picker: Browse mise config files
--- Source: mise config ls
local M = {}

local pickers = require("mise.pickers")

---@param opts? table
function M.pick(opts)
  if not pickers.check_snacks() then
    return
  end
  local Snacks = require("snacks")
  local util = require("mise.util")
  local cfg = require("mise.config").get()
  opts = vim.tbl_deep_extend("force", cfg.pickers.config or {}, opts or {})

  ---@type snacks.picker.finder
  local function finder(_opts, _ctx)
    return function(cb)
      local stdout, _, code = util.run({ "config", "ls" })
      if code ~= 0 then
        util.notify("mise config ls failed", vim.log.levels.ERROR)
        return
      end

      for _, line in ipairs(vim.split(stdout, "\n")) do
        line = vim.trim(line)
        if line == "" then
          goto continue
        end

        -- Output format varies: may be just path, or "path  tool1, tool2, ..."
        -- Try to parse path and optional tools list
        local path, tools_str = line:match("^(%S+)%s+(.+)$")
        if not path then
          path = line
          tools_str = nil
        end

        -- Expand ~ and resolve path
        local expanded = vim.fn.expand(path)
        local tools = {} ---@type string[]
        if tools_str then
          for _, t in ipairs(vim.split(tools_str, ",")) do
            t = vim.trim(t)
            if t ~= "" then
              tools[#tools + 1] = t
            end
          end
        end

        -- Check if file exists
        local exists = vim.fn.filereadable(expanded) == 1

        cb({
          text        = expanded .. " " .. table.concat(tools, " "),
          file        = expanded,
          config_path = expanded,
          tools       = tools,
          exists      = exists,
          -- Use snacks file previewer for TOML syntax highlighting
          preview     = "file",
        })

        ::continue::
      end
    end
  end

  ---@type snacks.picker.format
  local function format(item, _picker)
    local ret = {} ---@type snacks.picker.Highlight[]

    -- File icon
    local icon, icon_hl
    if item.exists then
      icon, icon_hl = " ", "SnacksPickerIcon"
    else
      icon, icon_hl = " ", "DiagnosticError"
    end
    ret[#ret + 1] = { icon .. " ", icon_hl, virtual = true }

    -- Config file path (shortened)
    local short = vim.fn.fnamemodify(item.config_path, ":~")
    -- Highlight the filename part differently from the directory
    local dir = vim.fn.fnamemodify(short, ":h")
    local base = vim.fn.fnamemodify(short, ":t")
    if dir and dir ~= "." and dir ~= short then
      ret[#ret + 1] = { dir .. "/", "SnacksPickerDir" }
      ret[#ret + 1] = { base, "SnacksPickerFile", field = "file" }
    else
      ret[#ret + 1] = { short, "SnacksPickerFile", field = "file" }
    end

    -- Tools list
    if #item.tools > 0 then
      ret[#ret + 1] = { "  " .. table.concat(item.tools, ", "), "SnacksPickerComment" }
    end

    return ret
  end

  local actions = {
    -- Trust the config file
    mise_trust = function(picker, item)
      pickers.close_and_run(
        picker,
        { "trust", item.config_path },
        "Trusted: " .. item.config_path,
        "Trust failed"
      )
    end,
    -- Revoke trust
    mise_untrust = function(picker, item)
      pickers.close_and_run(
        picker,
        { "trust", "--untrust", item.config_path },
        "Revoked trust: " .. item.config_path,
        "Untrust failed"
      )
    end,
  }

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title   = "Mise Config Files",
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
          ["<C-t>"] = { "mise_trust",   mode = { "n", "i" }, desc = "Trust config" },
          ["<C-u>"] = { "mise_untrust", mode = { "n", "i" }, desc = "Revoke trust" },
        },
      },
    },
  }, opts))
end

return M
