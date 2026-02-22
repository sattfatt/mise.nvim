--- Picker: Browse and run mise tasks
--- Source: mise tasks ls --json
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
  opts = vim.tbl_deep_extend("force", cfg.pickers.tasks or {}, opts or {})
  local cwd = util.cwd()

  local default_action = opts.default_action or "run"

  ---@type snacks.picker.finder
  local function finder(_opts, _ctx)
    return function(cb)
      local stdout, _, code = util.run({ "tasks", "ls", "--json" }, { cwd = cwd })
      if code ~= 0 then
        util.notify("mise tasks ls failed", vim.log.levels.ERROR)
        return
      end
      local tasks, err = util.json_decode(stdout)
      if not tasks then
        util.notify("Failed to parse tasks: " .. (err or ""), vim.log.levels.ERROR)
        return
      end

      -- tasks is an array of task objects
      if type(tasks) ~= "table" then
        return
      end

      for _, task in ipairs(tasks) do
        -- Skip hidden tasks
        if task.hide then
          goto continue
        end

        -- Build run script preview
        local run_scripts = task.run or {}
        if type(run_scripts) == "string" then
          run_scripts = { run_scripts }
        end
        local script_text = table.concat(run_scripts, "\n")

        local preview_lines = {
          "# " .. task.name,
        }
        if task.description and task.description ~= "" then
          preview_lines[#preview_lines + 1] = "# " .. task.description
        end
        preview_lines[#preview_lines + 1] = ""
        if task.depends and #task.depends > 0 then
          preview_lines[#preview_lines + 1] = "# depends: " .. table.concat(task.depends, ", ")
          preview_lines[#preview_lines + 1] = ""
        end
        if task.file then
          -- File-based task
          preview_lines[#preview_lines + 1] = "# file: " .. task.file
          preview_lines[#preview_lines + 1] = ""
        end
        if script_text ~= "" then
          preview_lines[#preview_lines + 1] = script_text
        end

        cb({
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
        })

        ::continue::
      end
    end
  end

  ---@type snacks.picker.format
  local function format(item, _picker)
    local ret = {} ---@type snacks.picker.Highlight[]

    -- Scope badge: [G]lobal or [L]ocal
    local scope_icon = item.is_global and "G" or "L"
    local scope_hl   = item.is_global and "SnacksPickerComment" or "DiagnosticHint"
    ret[#ret + 1] = { "[" .. scope_icon .. "] ", scope_hl, virtual = true }

    -- Task name: colorize namespace parts (colon-separated)
    local parts = vim.split(item.task_name, ":", { plain = true })
    for i, part in ipairs(parts) do
      if i < #parts then
        ret[#ret + 1] = { part, "SnacksPickerDir" }
        ret[#ret + 1] = { ":", "Comment", virtual = true }
      else
        ret[#ret + 1] = { part, "SnacksPickerLabel" }
      end
    end

    -- Description
    if item.description ~= "" then
      ret[#ret + 1] = { "  " .. item.description, "SnacksPickerComment" }
    end

    -- Dependency indicator
    if #item.depends > 0 then
      ret[#ret + 1] = { "  [deps:" .. #item.depends .. "]", "Comment", virtual = true }
    end

    return ret
  end

  local actions = {
    -- Run the task in a terminal
    mise_run = function(picker, item)
      picker:close()
      util.run_task(item.task_name, false)
    end,
    -- Watch-run the task
    mise_watch = function(picker, item)
      picker:close()
      util.run_task(item.task_name, true)
    end,
    -- Open source file at the task definition
    edit_source = function(picker, item)
      picker:close()
      if item.file then
        vim.cmd("edit " .. vim.fn.fnameescape(item.file))
        -- Try to jump to the task definition line
        local name = item.task_name
        -- Search for [tasks.name] or the task name in file-based tasks
        local patterns = {
          vim.fn.escape('\\[tasks\\.' .. name .. '\\]', "[]().*+?^${}|\\"),
          vim.fn.escape(name, "[]().*+?^${}|\\"),
        }
        for _, pat in ipairs(patterns) do
          local found = vim.fn.search(pat, "w")
          if found ~= 0 then
            break
          end
        end
      end
    end,
    -- Yank task name
    yank_name = function(picker, item)
      vim.fn.setreg('"', item.task_name)
      vim.fn.setreg("+", item.task_name)
      util.notify("Yanked: " .. item.task_name)
    end,
    -- Show task dependencies in a new picker
    show_deps = function(picker, item)
      if #item.depends == 0 then
        util.notify("Task '" .. item.task_name .. "' has no dependencies")
        return
      end
      picker:close()
      -- Re-open picker filtered to dependency tasks
      M.pick({ pattern = table.concat(item.depends, "|") })
    end,
  }

  -- Determine default <CR> action
  local confirm_action = default_action == "watch" and "mise_watch" or "mise_run"

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title       = "Mise Tasks",
    finder      = finder,
    format      = format,
    preview     = "preview",
    matcher     = {
      fuzzy     = true,
      smartcase = true,
    },
    actions     = actions,
    win = {
      input = {
        keys = {
          ["<CR>"]  = { confirm_action, mode = { "n", "i" }, desc = "Run task" },
          ["<C-r>"] = { "mise_run",     mode = { "n", "i" }, desc = "Run task" },
          ["<C-w>"] = { "mise_watch",   mode = { "n", "i" }, desc = "Watch task" },
          ["<C-e>"] = { "edit_source",  mode = { "n", "i" }, desc = "Edit source" },
          ["<C-y>"] = { "yank_name",    mode = { "n", "i" }, desc = "Yank task name" },
          ["<C-d>"] = { "show_deps",    mode = { "n", "i" }, desc = "Show dependencies" },
        },
      },
    },
  }, opts))
end

return M
