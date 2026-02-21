--- Picker: Browse the mise registry (3000+ available tools)
--- Source: mise registry (streamed text output)
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
  opts = vim.tbl_deep_extend("force", cfg.pickers.registry or {}, opts or {})

  local default_action = opts.default_action or "install"

  -- Capture cwd synchronously before the async finder runs
  local cwd = util.cwd()

  ---@type snacks.picker.finder
  local function finder(fopts, ctx)
    return require("snacks.picker.source.proc").proc(
      ctx:opts({
        cmd  = util.mise_bin(),
        args = { "registry" },
        cwd  = cwd,
        transform = function(item)
          local line = item.text
          if line == "" or line:match("^%s*$") then
            return false
          end

          -- Parse: "tool-name    backend1 backend2 ..."
          -- The registry uses variable-width whitespace alignment
          local name, rest = line:match("^(%S+)%s+(.+)$")
          if not name then
            -- Line might be just a tool name with no backends listed
            name = line:match("^(%S+)%s*$")
            if not name then
              return false
            end
            rest = ""
          end

          -- Split backends (space-separated)
          local backends = {} ---@type string[]
          for b in (rest or ""):gmatch("%S+") do
            backends[#backends + 1] = b
          end

          -- Build preview
          local preview_lines = { "tool: " .. name, "" }
          if #backends > 0 then
            preview_lines[#preview_lines + 1] = "backends:"
            for _, b in ipairs(backends) do
              preview_lines[#preview_lines + 1] = "  - " .. b
            end
          end

          item.tool_name = name
          item.backends  = backends
          item.text      = name
          item.preview   = pickers.make_preview(preview_lines, "yaml")
        end,
      }),
      ctx
    )
  end

  ---@type snacks.picker.format
  local function format(item, _picker)
    local ret = {} ---@type snacks.picker.Highlight[]

    -- Tool name
    ret[#ret + 1] = { item.tool_name, "SnacksPickerLabel" }

    -- Primary backend with color
    if item.backends and #item.backends > 0 then
      local primary = item.backends[1]
      local btype = pickers.backend_type(primary)
      local bhl   = pickers.backend_hl(primary)
      ret[#ret + 1] = { "  [" .. btype .. "]", bhl }

      -- Additional backends count
      if #item.backends > 1 then
        ret[#ret + 1] = { " +" .. (#item.backends - 1), "SnacksPickerComment", virtual = true }
      end
    end

    return ret
  end

  local actions = {
    -- Install the tool at latest version
    mise_install_latest = function(picker, item)
      local spec = item.tool_name .. "@latest"
      pickers.close_and_run(
        picker,
        { "install", spec },
        "Installed " .. spec,
        "Install failed"
      )
    end,
    -- Use the tool (install + add to config)
    mise_use_latest = function(picker, item)
      local spec = item.tool_name .. "@latest"
      pickers.close_and_run(
        picker,
        { "use", spec },
        "Now using " .. spec,
        "mise use failed"
      )
    end,
    -- Open versions picker for this tool
    mise_versions = function(picker, item)
      picker:close()
      require("mise.pickers.versions").pick({ tool = item.tool_name })
    end,
    -- Yank tool name
    yank_name = function(picker, item)
      vim.fn.setreg('"', item.tool_name)
      vim.fn.setreg("+", item.tool_name)
      util.notify("Yanked: " .. item.tool_name)
    end,
  }

  -- Pick default <CR> action based on caller's intent
  local confirm_action = default_action == "use" and "mise_use_latest" or "mise_install_latest"

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title   = "Mise Registry",
    finder  = finder,
    format  = format,
    preview = "preview",
    matcher = {
      fuzzy     = true,
      smartcase = true,
      -- Don't re-sort when query is empty — keep registry's natural order
      sort_empty = false,
    },
    actions = actions,
    win = {
      input = {
        keys = {
          ["<CR>"]  = { confirm_action,        mode = { "n", "i" }, desc = "Install latest" },
          ["<C-i>"] = { "mise_install_latest", mode = { "n", "i" }, desc = "Install latest" },
          ["<C-u>"] = { "mise_use_latest",     mode = { "n", "i" }, desc = "Use latest (add to config)" },
          ["<C-v>"] = { "mise_versions",       mode = { "n", "i" }, desc = "Browse versions" },
          ["<C-y>"] = { "yank_name",           mode = { "n", "i" }, desc = "Yank tool name" },
        },
      },
    },
  }, opts))
end

return M
