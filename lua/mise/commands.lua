local M = {}

function M.setup()
  local util = require("mise.util")
  local mise = require("mise")

  -- Helper: open a picker or run a direct command
  local function picker_or_run(picker_fn, direct_fn, arg)
    arg = arg and vim.trim(arg) or ""
    if arg == "" then
      picker_fn()
    else
      direct_fn(arg)
    end
  end

  -- :MiseTools — Browse installed tools
  vim.api.nvim_create_user_command("MiseTools", function()
    require("mise.pickers.tools").pick()
  end, { desc = "Browse installed mise tools" })

  -- :MiseTasks — Browse and run tasks
  vim.api.nvim_create_user_command("MiseTasks", function()
    require("mise.pickers.tasks").pick()
  end, { desc = "Browse mise tasks" })

  -- :MiseRun [TASK] — Run a task (picker if no arg)
  vim.api.nvim_create_user_command("MiseRun", function(cmd_opts)
    picker_or_run(
      function() require("mise.pickers.tasks").pick({ default_action = "run" }) end,
      function(task) util.run_task(task, false) end,
      cmd_opts.args
    )
  end, {
    desc = "Run a mise task",
    nargs = "?",
    complete = function(arglead)
      return mise.complete_tasks(arglead)
    end,
  })

  -- :MiseWatch [TASK] — Watch-run a task (picker if no arg)
  vim.api.nvim_create_user_command("MiseWatch", function(cmd_opts)
    picker_or_run(
      function() require("mise.pickers.tasks").pick({ default_action = "watch" }) end,
      function(task) util.run_task(task, true) end,
      cmd_opts.args
    )
  end, {
    desc = "Watch-run a mise task",
    nargs = "?",
    complete = function(arglead)
      return mise.complete_tasks(arglead)
    end,
  })

  -- :MiseInstall [TOOL@VERSION] — Install a tool
  vim.api.nvim_create_user_command("MiseInstall", function(cmd_opts)
    picker_or_run(
      function() require("mise.pickers.tools").pick() end,
      function(spec)
        util.notify("Installing " .. spec .. "...")
        util.run_async({ "install", spec }, function(_, stderr, code)
          if code == 0 then
            util.notify("Installed " .. spec)
            mise.invalidate_cache()
          else
            util.notify("Install failed: " .. stderr, vim.log.levels.ERROR)
          end
        end)
      end,
      cmd_opts.args
    )
  end, {
    desc = "Install a mise tool",
    nargs = "?",
    complete = function(arglead)
      return mise.complete_tools(arglead)
    end,
  })

  -- :MiseUninstall [TOOL@VERSION] — Uninstall a tool
  vim.api.nvim_create_user_command("MiseUninstall", function(cmd_opts)
    picker_or_run(
      function() require("mise.pickers.tools").pick({ default_action = "uninstall" }) end,
      function(spec)
        util.run_async({ "uninstall", spec }, function(_, stderr, code)
          if code == 0 then
            util.notify("Uninstalled " .. spec)
            mise.invalidate_cache()
          else
            util.notify("Uninstall failed: " .. stderr, vim.log.levels.ERROR)
          end
        end)
      end,
      cmd_opts.args
    )
  end, {
    desc = "Uninstall a mise tool version",
    nargs = "?",
    complete = function(arglead)
      return mise.complete_installed_tools(arglead)
    end,
  })

  -- :MiseUpgrade [TOOL] — Upgrade tools (outdated picker if no arg)
  vim.api.nvim_create_user_command("MiseUpgrade", function(cmd_opts)
    picker_or_run(
      function() require("mise.pickers.outdated").pick() end,
      function(tool)
        util.notify("Upgrading " .. tool .. "...")
        util.run_async({ "upgrade", tool }, function(_, stderr, code)
          if code == 0 then
            util.notify("Upgraded " .. tool)
            mise.invalidate_cache()
          else
            util.notify("Upgrade failed: " .. stderr, vim.log.levels.ERROR)
          end
        end)
      end,
      cmd_opts.args
    )
  end, {
    desc = "Upgrade a mise tool",
    nargs = "?",
    complete = function(arglead)
      return mise.complete_installed_tools(arglead)
    end,
  })

  -- :MiseUse [TOOL@VERSION] — Install + add to config (registry picker if no arg)
  vim.api.nvim_create_user_command("MiseUse", function(cmd_opts)
    picker_or_run(
      function() require("mise.pickers.registry").pick({ default_action = "use" }) end,
      function(spec)
        util.notify("Switching to " .. spec .. "...")
        util.run_async({ "use", spec }, function(_, stderr, code)
          if code == 0 then
            util.notify("Now using " .. spec)
            mise.invalidate_cache()
          else
            util.notify("mise use failed: " .. stderr, vim.log.levels.ERROR)
          end
        end)
      end,
      cmd_opts.args
    )
  end, {
    desc = "Install a tool and add it to mise.toml",
    nargs = "?",
    complete = function(arglead)
      return mise.complete_tools(arglead)
    end,
  })

  -- :MiseRegistry — Browse the mise registry
  vim.api.nvim_create_user_command("MiseRegistry", function()
    require("mise.pickers.registry").pick()
  end, { desc = "Browse the mise registry" })

  -- :MiseEnv — Browse mise environment variables
  vim.api.nvim_create_user_command("MiseEnv", function()
    require("mise.pickers.env").pick()
  end, { desc = "Browse mise environment variables" })

  -- :MiseOutdated — Show outdated tools
  vim.api.nvim_create_user_command("MiseOutdated", function()
    require("mise.pickers.outdated").pick()
  end, { desc = "Show outdated mise tools" })

  -- :MiseConfig — Browse mise config files
  vim.api.nvim_create_user_command("MiseConfig", function()
    require("mise.pickers.config").pick()
  end, { desc = "Browse mise config files" })

  -- :MisePlugins — Browse mise plugins
  vim.api.nvim_create_user_command("MisePlugins", function()
    require("mise.pickers.plugins").pick()
  end, { desc = "Browse mise plugins" })

  -- :MiseVersions TOOL — Browse versions of a specific tool
  vim.api.nvim_create_user_command("MiseVersions", function(cmd_opts)
    local tool = vim.trim(cmd_opts.args)
    if tool == "" then
      util.notify("Usage: :MiseVersions <tool>", vim.log.levels.WARN)
      return
    end
    require("mise.pickers.versions").pick({ tool = tool })
  end, {
    desc = "Browse available versions for a mise tool",
    nargs = 1,
    complete = function(arglead)
      return mise.complete_installed_tools(arglead)
    end,
  })

  -- :MiseDoctor — Run mise doctor
  vim.api.nvim_create_user_command("MiseDoctor", function()
    util.notify("Running mise doctor...")
    util.run_async({ "doctor" }, function(stdout, _, _)
      -- Show in a floating window via notify
      util.notify(stdout, vim.log.levels.INFO)
    end)
  end, { desc = "Run mise doctor" })

  -- :MiseTrust [FILE] — Trust a config file
  vim.api.nvim_create_user_command("MiseTrust", function(cmd_opts)
    local file = vim.trim(cmd_opts.args)
    local args = file ~= "" and { "trust", file } or { "trust" }
    util.run_async(args, function(_, stderr, code)
      if code == 0 then
        util.notify("Config file trusted")
      else
        util.notify("Trust failed: " .. stderr, vim.log.levels.ERROR)
      end
    end)
  end, {
    desc = "Trust a mise config file",
    nargs = "?",
    complete = "file",
  })

  -- :MiseWhere TOOL — Show installation path for a tool
  vim.api.nvim_create_user_command("MiseWhere", function(cmd_opts)
    local tool = vim.trim(cmd_opts.args)
    if tool == "" then
      util.notify("Usage: :MiseWhere <tool>", vim.log.levels.WARN)
      return
    end
    local stdout, stderr, code = util.run({ "where", tool })
    if code == 0 then
      local path = vim.trim(stdout)
      util.notify(tool .. ": " .. path)
      vim.fn.setreg("+", path)
    else
      util.notify("mise where failed: " .. stderr, vim.log.levels.ERROR)
    end
  end, {
    desc = "Show installation path for a mise tool (also copies to clipboard)",
    nargs = 1,
    complete = function(arglead)
      return mise.complete_installed_tools(arglead)
    end,
  })
end

return M
