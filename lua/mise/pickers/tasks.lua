--- Picker: Browse and run mise tasks
--- Source: mise tasks ls --json (fetched on main thread before picker opens)
local M = {}

local pickers = require("mise.pickers")

---@param opts? table
function M.pick(opts)
  if not pickers.check_snacks() then return end
  local Snacks = require("snacks")
  local util = require("mise.util")
  local cfg = require("mise.config").get()
  opts = vim.tbl_deep_extend("force", cfg.pickers.tasks or {}, opts or {})

  local stdout, _, code = util.run({ "tasks", "ls", "--json" }, { cwd = util.cwd() })
  if code ~= 0 then
    util.notify("mise tasks ls failed", vim.log.levels.ERROR)
    return
  end
  local tasks, err = util.json_decode(stdout)
  if not tasks or type(tasks) ~= "table" then
    util.notify("Failed to parse tasks: " .. (err or ""), vim.log.levels.ERROR)
    return
  end

  local items = {} ---@type snacks.picker.finder.Item[]
  for _, task in ipairs(tasks) do
    if not task.hide then
      local run_scripts = task.run or {}
      if type(run_scripts) == "string" then run_scripts = { run_scripts } end
      local preview_lines = { "# " .. task.name }
      if task.description and task.description ~= "" then
        preview_lines[#preview_lines + 1] = "# " .. task.description
      end
      preview_lines[#preview_lines + 1] = ""
      if task.depends and #task.depends > 0 then
        preview_lines[#preview_lines + 1] = "# depends: " .. table.concat(task.depends, ", ")
        preview_lines[#preview_lines + 1] = ""
      end
      if task.file then
        preview_lines[#preview_lines + 1] = "# file: " .. task.file
        preview_lines[#preview_lines + 1] = ""
      end
      local script_text = table.concat(run_scripts, "\n")
      if script_text ~= "" then
        preview_lines[#preview_lines + 1] = script_text
      end
      items[#items + 1] = {
        text        = task.name .. " " .. (task.description or ""),
        task_name   = task.name,
        description = task.description or "",
        source      = task.source,
        file        = task.source,
        run_scripts = run_scripts,
        depends     = task.depends or {},
        is_global   = task.global or false,
        task_dir    = task.dir,
        task_file   = task.file,
        preview     = pickers.make_preview(preview_lines, "bash"),
      }
    end
  end

  ---@type snacks.picker.format
  local function format(item, _picker)
    local ret = {}
    -- Global/local scope icon
    if item.is_global then
      ret[#ret + 1] = { " 󰘆 ", "DiagnosticHint", virtual = true }  -- globe
    else
      ret[#ret + 1] = { "   ", "SnacksPickerComment", virtual = true } -- indent for alignment
    end
    -- Task name: use Normal so match highlights (SnacksPickerMatch) stand out on top
    ret[#ret + 1] = { item.task_name, "Normal", field = "text" }
    -- Description dimmed
    if item.description ~= "" then
      ret[#ret + 1] = { "  " .. item.description, "SnacksPickerComment" }
    end
    return ret
  end

  local actions = {
    mise_run = function(picker, item)
      picker:close()
      util.run_task(item.task_name, false)
    end,
    mise_watch = function(picker, item)
      picker:close()
      util.run_task(item.task_name, true)
    end,
    edit_source = function(picker, item)
      picker:close()
      if item.file then
        vim.cmd("edit " .. vim.fn.fnameescape(item.file))
        local name = item.task_name
        local patterns = {
          vim.fn.escape("\\[tasks\\." .. name .. "\\]", "[]().*+?^${}|\\"),
          vim.fn.escape(name, "[]().*+?^${}|\\"),
        }
        for _, pat in ipairs(patterns) do
          if vim.fn.search(pat, "w") ~= 0 then break end
        end
      end
    end,
    yank_name = function(picker, item)
      vim.fn.setreg('"', item.task_name)
      vim.fn.setreg("+", item.task_name)
      util.notify("Yanked: " .. item.task_name)
    end,
    show_deps = function(picker, item)
      if #item.depends == 0 then
        util.notify("Task '" .. item.task_name .. "' has no dependencies")
        return
      end
      picker:close()
      M.pick({ pattern = table.concat(item.depends, "|") })
    end,
  }

  local default_action = opts.default_action or "run"
  local confirm_action = default_action == "watch" and "mise_watch" or "mise_run"

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title   = "Mise Tasks",
    finder  = function() return items end,
    format  = format,
    preview = "preview",
    matcher = { fuzzy = true, smartcase = true },
    actions = actions,
    win = { input = {
      footer = pickers.make_footer({
        ["<CR>"]  = { desc = "Run" },
        ["<C-w>"] = { desc = "Watch" },
        ["<C-e>"] = { desc = "Edit" },
        ["<C-y>"] = { desc = "Yank" },
        ["<C-d>"] = { desc = "Deps" },
      }),
      footer_pos = "left",
      keys = {
        ["<CR>"]  = { confirm_action, mode = { "n", "i" }, desc = "Run task" },
        ["<C-r>"] = { "mise_run",     mode = { "n", "i" }, desc = "Run task" },
        ["<C-w>"] = { "mise_watch",   mode = { "n", "i" }, desc = "Watch task" },
        ["<C-e>"] = { "edit_source",  mode = { "n", "i" }, desc = "Edit source" },
        ["<C-y>"] = { "yank_name",    mode = { "n", "i" }, desc = "Yank task name" },
        ["<C-d>"] = { "show_deps",    mode = { "n", "i" }, desc = "Show dependencies" },
      },
    }},
  }, opts))
end

return M
