local helpers = require("tests.helpers")

describe("mise (public API)", function()
  before_each(function()
    helpers.reset_mise()
    require("mise.config").setup()
  end)

  describe("setup()", function()
    it("does not error with empty opts", function()
      assert.has_no.errors(function()
        require("mise").setup()
      end)
    end)

    it("does not error with valid opts", function()
      assert.has_no.errors(function()
        require("mise").setup({
          mise_path = "mise",
          cwd = "cwd",
          terminal = { split = "horizontal", height = 20 },
        })
      end)
    end)

    it("registers user commands after setup", function()
      require("mise").setup()
      -- Check a few key commands were registered
      local cmds = vim.api.nvim_get_commands({})
      assert.is_not_nil(cmds["MiseTools"])
      assert.is_not_nil(cmds["MiseTasks"])
      assert.is_not_nil(cmds["MiseRun"])
      assert.is_not_nil(cmds["MiseInstall"])
      assert.is_not_nil(cmds["MiseUpgrade"])
      assert.is_not_nil(cmds["MiseRegistry"])
      assert.is_not_nil(cmds["MiseEnv"])
      assert.is_not_nil(cmds["MiseOutdated"])
      assert.is_not_nil(cmds["MiseConfig"])
      assert.is_not_nil(cmds["MisePlugins"])
      assert.is_not_nil(cmds["MiseDoctor"])
      assert.is_not_nil(cmds["MiseTrust"])
      assert.is_not_nil(cmds["MiseWhere"])
      assert.is_not_nil(cmds["MiseVersions"])
    end)
  end)

  describe("invalidate_cache()", function()
    it("does not error", function()
      local mise = require("mise")
      assert.has_no.errors(function()
        mise.invalidate_cache()
      end)
    end)

    it("clears cached tool versions", function()
      local util = require("mise.util")
      if not util.check_mise() then
        pending("mise not found in PATH")
        return
      end

      local mise = require("mise")
      -- Populate the cache
      mise.get_tool_version("node") -- may return nil, but populates _cache

      -- Invalidate
      mise.invalidate_cache()

      -- Next call should re-run mise (not crash)
      assert.has_no.errors(function()
        mise.get_tool_version("node")
      end)
    end)
  end)

  describe("get_tool_version()", function()
    it("returns nil when mise is not available", function()
      require("mise.config").setup({ mise_path = "/nonexistent/mise_xyz" })
      local mise = require("mise")
      local result = mise.get_tool_version("node")
      assert.is_nil(result)
    end)

    it("returns a string or nil when mise is available", function()
      local util = require("mise.util")
      if not util.check_mise() then
        pending("mise not found in PATH")
        return
      end
      local mise = require("mise")
      local result = mise.get_tool_version("node")
      -- Result is either a version string or nil (tool may not be installed)
      assert(result == nil or type(result) == "string")
    end)

    it("caches the result on repeated calls", function()
      local util = require("mise.util")
      if not util.check_mise() then
        pending("mise not found in PATH")
        return
      end

      local call_count = 0
      local original_run = util.run
      util.run = function(args, opts)
        -- Count calls to util.run
        if args[1] == "current" then
          call_count = call_count + 1
        end
        return original_run(args, opts)
      end

      local mise = require("mise")
      mise.get_tool_version("node")
      mise.get_tool_version("node") -- second call should use cache

      util.run = original_run

      -- Should only have called run once
      assert.equals(1, call_count)
    end)
  end)

  describe("get_active_tools()", function()
    it("returns a table", function()
      local util = require("mise.util")
      if not util.check_mise() then
        pending("mise not found in PATH")
        return
      end
      local mise = require("mise")
      local result = mise.get_active_tools()
      assert.is_table(result)
    end)

    it("returns empty table when mise is not available", function()
      require("mise.config").setup({ mise_path = "/nonexistent/mise_xyz" })
      local mise = require("mise")
      local result = mise.get_active_tools()
      assert.are.same({}, result)
    end)

    it("each entry has name and version fields", function()
      local util = require("mise.util")
      if not util.check_mise() then
        pending("mise not found in PATH")
        return
      end
      local mise = require("mise")
      local tools = mise.get_active_tools()
      for _, t in ipairs(tools) do
        assert.is_string(t.name)
        assert.is_string(t.version)
        assert.is_not_nil(t.name)
        assert.is_not_nil(t.version)
      end
    end)
  end)

  describe("complete_tasks()", function()
    it("returns a table", function()
      local util = require("mise.util")
      if not util.check_mise() then
        pending("mise not found in PATH")
        return
      end
      local mise = require("mise")
      local result = mise.complete_tasks("")
      assert.is_table(result)
    end)

    it("returns empty table when mise is not available", function()
      require("mise.config").setup({ mise_path = "/nonexistent/mise_xyz" })
      local mise = require("mise")
      local result = mise.complete_tasks("")
      assert.are.same({}, result)
    end)
  end)

  describe("complete_installed_tools()", function()
    it("returns a table", function()
      local util = require("mise.util")
      if not util.check_mise() then
        pending("mise not found in PATH")
        return
      end
      local mise = require("mise")
      local result = mise.complete_installed_tools("")
      assert.is_table(result)
      -- Each item should be a string
      for _, v in ipairs(result) do
        assert.is_string(v)
      end
    end)
  end)
end)
