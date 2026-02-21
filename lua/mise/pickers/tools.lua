--- Picker: Browse installed mise tools
--- Source: mise ls --json
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
  opts = vim.tbl_deep_extend("force", cfg.pickers.tools or {}, opts or {})

  ---@type snacks.picker.finder
  local function finder(_opts, _ctx)
    -- Capture cwd synchronously before entering the async callback
    local cwd = util.cwd()
    return function(cb)
      local stdout, _, code = util.run({ "ls", "--json" }, { cwd = cwd })
      if code ~= 0 then
        util.notify("mise ls failed", vim.log.levels.ERROR)
        return
      end
      local data, err = util.json_decode(stdout)
      if not data then
        util.notify("Failed to parse mise ls output: " .. (err or ""), vim.log.levels.ERROR)
        return
      end

      -- data is { "tool-name": [{version, active, installed, source, install_path, requested_version}] }
      local tool_keys = vim.tbl_keys(data)
      table.sort(tool_keys)

      for _, tool_key in ipairs(tool_keys) do
        local versions = data[tool_key]
        if type(versions) == "table" then
          local parsed = pickers.parse_tool_key(tool_key)

          for _, v in ipairs(versions) do
            local source_path = v.source and v.source.path or nil
            local install_path = v.install_path or ""

            -- Build preview text
            local preview_lines = {
              "tool: " .. tool_key,
              "version: " .. (v.version or ""),
              "active: " .. tostring(v.active or false),
              "installed: " .. tostring(v.installed or false),
              "requested: " .. (v.requested_version or ""),
              "install_path: " .. install_path,
            }
            if source_path then
              preview_lines[#preview_lines + 1] = "source: " .. source_path
              preview_lines[#preview_lines + 1] = "source_type: " .. (v.source and v.source.type or "")
            end

            cb({
              -- Searchable text: tool name + version
              text        = tool_key .. " " .. (v.version or ""),
              -- Display fields
              tool_key    = tool_key,
              tool_name   = parsed.name,
              backend     = parsed.backend,
              version     = v.version or "",
              active      = v.active or false,
              installed   = v.installed or false,
              requested   = v.requested_version or "",
              install_path = install_path,
              source_path = source_path,
              -- For file-jump on <CR>
              file        = source_path,
              -- For snacks built-in "preview" previewer
              preview     = pickers.make_preview(preview_lines, "yaml"),
            })
          end
        end
      end
    end
  end

  ---@type snacks.picker.format
  local function format(item, _picker)
    local ret = {} ---@type snacks.picker.Highlight[]

    -- Status icon
    local icon, icon_hl
    if item.active then
      icon, icon_hl = "●", "DiagnosticOk"
    elseif item.installed then
      icon, icon_hl = "○", "Comment"
    else
      icon, icon_hl = "✗", "DiagnosticError"
    end
    ret[#ret + 1] = { icon .. " ", icon_hl, virtual = true }

    -- Backend badge (for non-core tools like cargo:, npm:, etc.)
    if item.backend then
      local bhl = pickers.backend_hl(item.backend .. ":")
      ret[#ret + 1] = { "[" .. item.backend .. "] ", bhl, virtual = true }
    end

    -- Tool name
    ret[#ret + 1] = { item.tool_name, "SnacksPickerLabel" }

    -- Version
    ret[#ret + 1] = { " " .. item.version, "SnacksPickerComment" }

    -- Source path (for active tools only)
    if item.active and item.source_path then
      local short = vim.fn.fnamemodify(item.source_path, ":~")
      ret[#ret + 1] = { "  " .. short, "SnacksPickerDir" }
    end

    return ret
  end

  local actions = {
    -- Install the selected tool version
    mise_install = function(picker, item)
      local spec = item.tool_key .. "@" .. item.version
      pickers.close_and_run(
        picker,
        { "install", spec },
        "Installed " .. spec,
        "Install failed"
      )
    end,
    -- Uninstall with confirmation
    mise_uninstall = function(picker, item)
      local spec = item.tool_key .. "@" .. item.version
      pickers.confirm("Uninstall " .. spec .. "?", function()
        pickers.close_and_run(
          picker,
          { "uninstall", spec },
          "Uninstalled " .. spec,
          "Uninstall failed"
        )
      end)
    end,
    -- Upgrade the tool
    mise_upgrade = function(picker, item)
      pickers.close_and_run(
        picker,
        { "upgrade", item.tool_key },
        "Upgraded " .. item.tool_key,
        "Upgrade failed"
      )
    end,
    -- Open the versions picker for this tool
    mise_versions = function(picker, item)
      picker:close()
      require("mise.pickers.versions").pick({ tool = item.tool_key })
    end,
    -- Yank tool@version to clipboard
    yank_spec = function(picker, item)
      local spec = item.tool_key .. "@" .. item.version
      vim.fn.setreg('"', spec)
      vim.fn.setreg("+", spec)
      util.notify("Yanked: " .. spec)
    end,
  }

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title = "Mise Tools",
    finder = finder,
    format = format,
    preview = "preview",
    matcher = {
      fuzzy = true,
      smartcase = true,
    },
    actions = actions,
    win = {
      input = {
        keys = {
          ["<C-i>"] = { "mise_install",   mode = { "n", "i" }, desc = "Install" },
          ["<C-x>"] = { "mise_uninstall", mode = { "n", "i" }, desc = "Uninstall" },
          ["<C-u>"] = { "mise_upgrade",   mode = { "n", "i" }, desc = "Upgrade" },
          ["<C-v>"] = { "mise_versions",  mode = { "n", "i" }, desc = "Browse versions" },
          ["<C-y>"] = { "yank_spec",      mode = { "n", "i" }, desc = "Yank tool@version" },
        },
      },
    },
  }, opts))
end

return M
