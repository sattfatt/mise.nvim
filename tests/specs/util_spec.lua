local helpers = require("tests.helpers")

describe("mise.util", function()
  before_each(function()
    helpers.reset_mise()
    -- Set up default config before each test
    require("mise.config").setup()
  end)

  describe("mise_bin()", function()
    it("returns the configured mise_path", function()
      require("mise.config").setup({ mise_path = "/custom/mise" })
      local util = require("mise.util")
      assert.equals("/custom/mise", util.mise_bin())
    end)

    it("returns 'mise' by default", function()
      local util = require("mise.util")
      assert.equals("mise", util.mise_bin())
    end)
  end)

  describe("json_decode()", function()
    it("decodes valid JSON object", function()
      local util = require("mise.util")
      local result, err = util.json_decode('{"key": "value", "num": 42}')
      assert.is_nil(err)
      assert.is_table(result)
      assert.equals("value", result.key)
      assert.equals(42, result.num)
    end)

    it("decodes valid JSON array", function()
      local util = require("mise.util")
      local result, err = util.json_decode('[1, 2, 3]')
      assert.is_nil(err)
      assert.is_table(result)
      assert.equals(3, #result)
    end)

    it("decodes empty object without error", function()
      local util = require("mise.util")
      local result, err = util.json_decode('{}')
      assert.is_nil(err)
      assert.is_table(result)
    end)

    it("returns nil and error for invalid JSON", function()
      local util = require("mise.util")
      local result, err = util.json_decode('not valid json {')
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)

    it("returns nil and error for empty string", function()
      local util = require("mise.util")
      local result, err = util.json_decode('')
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)

    it("handles null values in JSON", function()
      local util = require("mise.util")
      local result, err = util.json_decode('{"key": null, "arr": [null]}')
      assert.is_nil(err)
      assert.is_table(result)
      -- vim.json.decode with luanil returns vim.NIL or nil
    end)
  end)

  describe("has_snacks()", function()
    it("returns a boolean", function()
      local util = require("mise.util")
      local result = util.has_snacks()
      assert.is_boolean(result)
    end)
  end)

  describe("cwd()", function()
    it("returns current directory in 'cwd' mode", function()
      require("mise.config").setup({ cwd = "cwd" })
      local util = require("mise.util")
      local result = util.cwd()
      assert.is_string(result)
      assert.equals(vim.fn.getcwd(), result)
    end)

    it("returns a string in 'root' mode", function()
      require("mise.config").setup({ cwd = "root" })
      local util = require("mise.util")
      local result = util.cwd()
      assert.is_string(result)
      assert.is_not_nil(result)
    end)
  end)

  describe("run()", function()
    it("returns stdout, stderr, and exit code", function()
      -- Use a known-good command: mise --version
      local util = require("mise.util")
      -- Only run if mise is actually available
      if not util.check_mise() then
        pending("mise not found in PATH")
        return
      end
      local stdout, stderr, code = util.run({ "--version" })
      assert.is_string(stdout)
      assert.is_string(stderr)
      assert.is_number(code)
      assert.equals(0, code)
      assert.truthy(stdout:find("mise") or stdout:find("%d+%.%d+"))
    end)

    it("returns non-zero code for invalid command", function()
      local util = require("mise.util")
      if not util.check_mise() then
        pending("mise not found in PATH")
        return
      end
      local _, _, code = util.run({ "this-command-does-not-exist-xyz" })
      assert.is_number(code)
      assert.not_equals(0, code)
    end)
  end)

  describe("run_async()", function()
    it("calls callback with stdout, stderr, and code", function()
      local util = require("mise.util")
      if not util.check_mise() then
        pending("mise not found in PATH")
        return
      end

      local called = false
      local got_stdout, got_code

      util.run_async({ "--version" }, function(stdout, _, code)
        called = true
        got_stdout = stdout
        got_code = code
      end)

      -- Wait for the async callback to fire
      vim.wait(3000, function() return called end)

      assert.is_true(called)
      assert.equals(0, got_code)
      assert.is_string(got_stdout)
    end)
  end)

  describe("check_mise()", function()
    it("returns a boolean", function()
      local util = require("mise.util")
      local result = util.check_mise()
      assert.is_boolean(result)
    end)

    it("returns false for a non-existent binary", function()
      require("mise.config").setup({ mise_path = "/definitely/not/a/real/binary/xyz123" })
      local util = require("mise.util")
      assert.is_false(util.check_mise())
    end)
  end)

  describe("notify()", function()
    it("calls vim.notify with mise title", function()
      local notifications, restore = helpers.capture_notifications()
      local util = require("mise.util")

      util.notify("hello from mise")

      restore()

      assert.equals(1, #notifications)
      assert.equals("hello from mise", notifications[1].msg)
      assert.equals("mise", notifications[1].opts.title)
    end)

    it("uses specified log level", function()
      local notifications, restore = helpers.capture_notifications()
      local util = require("mise.util")

      util.notify("error message", vim.log.levels.ERROR)

      restore()

      assert.equals(vim.log.levels.ERROR, notifications[1].level)
    end)

    it("defaults to INFO level", function()
      local notifications, restore = helpers.capture_notifications()
      local util = require("mise.util")

      util.notify("info message")

      restore()

      assert.equals(vim.log.levels.INFO, notifications[1].level)
    end)
  end)
end)
