--- Picker: Browse available versions for a specific tool
--- Source: mise ls-remote TOOL (streamed, one version per line)
local M = {}

local pickers = require("mise.pickers")

---@param opts? {tool?: string}
function M.pick(opts)
  if not pickers.check_snacks() then
    return
  end
  opts = opts or {}

  local tool = opts.tool
  if not tool or tool == "" then
    require("mise.util").notify("versions picker requires a tool name", vim.log.levels.WARN)
    return
  end

  local Snacks = require("snacks")
  local util = require("mise.util")
  local cfg = require("mise.config").get()
  local picker_opts = vim.tbl_deep_extend("force", cfg.pickers.versions or {}, opts)

  -- Capture cwd synchronously (used for both the pre-fetch and the proc finder)
  local cwd = util.cwd()

  -- Pre-fetch installed versions for this tool to show badges
  local installed_versions = {} ---@type table<string, boolean>
  local ls_stdout, _, ls_code = util.run({ "ls", "--json" }, { cwd = cwd })
  if ls_code == 0 then
    local data = util.json_decode(ls_stdout)
    if data and data[tool] and type(data[tool]) == "table" then
      for _, v in ipairs(data[tool]) do
        if v.version then
          installed_versions[v.version] = true
        end
      end
    end
  end

  ---@type snacks.picker.finder
  local function finder(fopts, ctx)
    return require("snacks.picker.source.proc").proc(
      ctx:opts({
        cmd  = util.mise_bin(),
        args = { "ls-remote", tool },
        cwd  = cwd,
        transform = function(item)
          local ver = vim.trim(item.text)
          if ver == "" then
            return false
          end
          item.version   = ver
          item.tool_key  = tool
          item.installed = installed_versions[ver] or false
          item.text      = ver
          item.preview   = pickers.make_preview({
            "tool: " .. tool,
            "version: " .. ver,
            "installed: " .. tostring(installed_versions[ver] or false),
          }, "yaml")
        end,
      }),
      ctx
    )
  end

  ---@type snacks.picker.format
  local function format(item, _picker)
    local ret = {} ---@type snacks.picker.Highlight[]

    -- Installation badge
    if item.installed then
      ret[#ret + 1] = { "✓ ", "DiagnosticOk", virtual = true }
    else
      ret[#ret + 1] = { "  ", "Normal", virtual = true }
    end

    -- Version number
    ret[#ret + 1] = { item.version, item.installed and "SnacksPickerLabel" or "Normal" }

    if item.installed then
      ret[#ret + 1] = { "  installed", "DiagnosticOk", virtual = true }
    end

    return ret
  end

  local actions = {
    -- mise use TOOL@VER (installs + adds to config)
    mise_use = function(picker, item)
      local spec = item.tool_key .. "@" .. item.version
      pickers.close_and_run(
        picker,
        { "use", spec },
        "Now using " .. spec,
        "mise use failed"
      )
    end,
    -- mise install TOOL@VER (install only, no config change)
    mise_install = function(picker, item)
      local spec = item.tool_key .. "@" .. item.version
      pickers.close_and_run(
        picker,
        { "install", spec },
        "Installed " .. spec,
        "Install failed"
      )
    end,
    -- Yank version spec
    yank_spec = function(picker, item)
      local spec = item.tool_key .. "@" .. item.version
      vim.fn.setreg('"', spec)
      vim.fn.setreg("+", spec)
      require("mise.util").notify("Yanked: " .. spec)
    end,
  }

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title   = "Mise Versions: " .. tool,
    finder  = finder,
    format  = format,
    preview = "preview",
    matcher = {
      fuzzy     = true,
      smartcase = true,
    },
    sort = {
      -- Keep original order (versions are already ordered by mise ls-remote)
      fields = { "idx:asc" },
    },
    actions = actions,
    win = {
      input = {
        footer_keys = true,
        keys = {
          ["<CR>"]  = { "mise_use",     mode = { "n", "i" }, desc = "Use this version (mise use)" },
          ["<C-i>"] = { "mise_install", mode = { "n", "i" }, desc = "Install only" },
          ["<C-y>"] = { "yank_spec",    mode = { "n", "i" }, desc = "Yank tool@version" },
        },
      },
    },
  }, picker_opts))
end

return M
