local helpers = require("tests.helpers")

describe("mise.commands", function()
  before_each(function()
    helpers.reset_mise()
    require("mise.config").setup()
    -- Commands are registered on setup
    require("mise").setup()
  end)

  after_each(function()
    -- Clean up any user commands created during tests
    -- (they persist across tests since nvim_create_user_command is global)
  end)

  -- Helper: check that a command exists and has correct attributes
  local function assert_command(name, opts)
    local cmds = vim.api.nvim_get_commands({})
    local cmd = cmds[name]
    assert.is_not_nil(cmd, "Command :" .. name .. " should exist")
    if opts then
      if opts.nargs then
        assert.equals(opts.nargs, cmd.nargs, name .. " nargs mismatch")
      end
    end
  end

  describe("command registration", function()
    it("registers :MiseTools", function()
      assert_command("MiseTools")
    end)

    it("registers :MiseTasks", function()
      assert_command("MiseTasks")
    end)

    it("registers :MiseRun with optional arg", function()
      assert_command("MiseRun", { nargs = "?" })
    end)

    it("registers :MiseWatch with optional arg", function()
      assert_command("MiseWatch", { nargs = "?" })
    end)

    it("registers :MiseInstall with optional arg", function()
      assert_command("MiseInstall", { nargs = "?" })
    end)

    it("registers :MiseUninstall with optional arg", function()
      assert_command("MiseUninstall", { nargs = "?" })
    end)

    it("registers :MiseUpgrade with optional arg", function()
      assert_command("MiseUpgrade", { nargs = "?" })
    end)

    it("registers :MiseUse with optional arg", function()
      assert_command("MiseUse", { nargs = "?" })
    end)

    it("registers :MiseRegistry", function()
      assert_command("MiseRegistry")
    end)

    it("registers :MiseEnv", function()
      assert_command("MiseEnv")
    end)

    it("registers :MiseOutdated", function()
      assert_command("MiseOutdated")
    end)

    it("registers :MiseConfig", function()
      assert_command("MiseConfig")
    end)

    it("registers :MisePlugins", function()
      assert_command("MisePlugins")
    end)

    it("registers :MiseDoctor", function()
      assert_command("MiseDoctor")
    end)

    it("registers :MiseTrust with optional arg", function()
      assert_command("MiseTrust", { nargs = "?" })
    end)

    it("registers :MiseWhere with 1 required arg", function()
      assert_command("MiseWhere", { nargs = "1" })
    end)

    it("registers :MiseVersions with 1 required arg", function()
      assert_command("MiseVersions", { nargs = "1" })
    end)
  end)

  describe(":MiseInstall with argument", function()
    it("runs mise install async and notifies on success", function()
      local util = require("mise.util")
      if not util.check_mise() then
        pending("mise not found in PATH")
        return
      end

      local notifications, restore = helpers.capture_notifications()

      -- Stub run_async to avoid real network calls
      local original_run_async = util.run_async
      local called_with_args
      util.run_async = function(args, cb, opts)
        called_with_args = args
        -- Simulate success
        vim.schedule(function()
          cb("", "", 0)
        end)
      end

      vim.cmd("MiseInstall bat@latest")
      vim.wait(200, function() return #notifications >= 2 end)

      util.run_async = original_run_async
      restore()

      -- Should have called install
      assert.is_not_nil(called_with_args)
      assert.equals("install", called_with_args[1])
      assert.equals("bat@latest", called_with_args[2])

      -- Should have notified "Installing..." and "Installed ..."
      assert.is_true(#notifications >= 1)
    end)

    it("notifies on install failure", function()
      local util = require("mise.util")
      local notifications, restore = helpers.capture_notifications()

      local original_run_async = util.run_async
      util.run_async = function(args, cb, _)
        if args[1] == "install" then
          vim.schedule(function()
            cb("", "tool not found", 1)
          end)
        end
      end

      vim.cmd("MiseInstall nonexistent-tool-xyz@1.0.0")
      vim.wait(200, function() return #notifications >= 2 end)

      util.run_async = original_run_async
      restore()

      -- Should have an error notification
      local has_error = false
      for _, n in ipairs(notifications) do
        if n.level == vim.log.levels.ERROR then
          has_error = true
          break
        end
      end
      assert.is_true(has_error, "Expected an error notification")
    end)
  end)

  describe(":MiseWhere with argument", function()
    it("shows install path when tool is found", function()
      local util = require("mise.util")
      if not util.check_mise() then
        pending("mise not found in PATH")
        return
      end

      local original_run = util.run
      util.run = function(args, opts)
        if args[1] == "where" then
          return "/home/user/.local/share/mise/installs/bat/0.24.0", "", 0
        end
        return original_run(args, opts)
      end

      local notifications, restore = helpers.capture_notifications()
      vim.cmd("MiseWhere bat")
      restore()
      util.run = original_run

      assert.is_true(#notifications >= 1)
      assert.truthy(notifications[1].msg:find("bat"))
    end)
  end)

  describe(":MiseDoctor", function()
    it("runs without error when mise is available", function()
      local util = require("mise.util")
      if not util.check_mise() then
        pending("mise not found in PATH")
        return
      end

      local original_run_async = util.run_async
      local called = false
      util.run_async = function(args, cb, _)
        if args[1] == "doctor" then
          called = true
          vim.schedule(function()
            cb("mise is activated: yes\n", "", 0)
          end)
        end
      end

      assert.has_no.errors(function()
        vim.cmd("MiseDoctor")
      end)
      vim.wait(200, function() return called end)

      util.run_async = original_run_async
      assert.is_true(called)
    end)
  end)
end)
