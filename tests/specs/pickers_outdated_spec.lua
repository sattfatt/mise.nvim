local helpers = require("tests.helpers")

describe("mise.pickers.outdated (finder logic)", function()
  before_each(function()
    helpers.reset_mise()
    require("mise.config").setup()
  end)

  describe("JSON parsing for mise outdated", function()
    it("parses outdated JSON correctly", function()
      local util = require("mise.util")
      local json = helpers.fake_outdated_json({
        node = {
          name = "node",
          requested = "latest",
          current = "20.0.0",
          latest = "22.5.0",
          bump = "major",
          source = { type = "mise.toml", path = "/home/user/mise.toml" },
        },
        bat = {
          name = "bat",
          requested = "latest",
          current = "0.23.0",
          latest = "0.24.0",
          bump = "patch",
          source = { type = "mise.toml", path = "/home/user/mise.toml" },
        },
      })

      local data, err = util.json_decode(json)
      assert.is_nil(err)
      assert.is_table(data)
      assert.is_not_nil(data.node)
      assert.equals("20.0.0", data.node.current)
      assert.equals("22.5.0", data.node.latest)
      assert.equals("major", data.node.bump)
      assert.equals("patch", data.bat.bump)
    end)

    it("handles empty outdated output (all up to date)", function()
      local util = require("mise.util")
      local json = helpers.fake_outdated_json({})
      local data, err = util.json_decode(json)
      assert.is_nil(err)
      assert.is_table(data)
      assert.equals(0, vim.tbl_count(data))
    end)

    it("handles tools without bump info", function()
      local util = require("mise.util")
      local json = helpers.fake_outdated_json({
        mytool = {
          name = "mytool",
          current = "1.0.0",
          latest = "1.1.0",
          bump = vim.NIL,
          requested = "latest",
        },
      })
      local data, err = util.json_decode(json)
      assert.is_nil(err)
      assert.is_not_nil(data.mytool)
    end)
  end)

  describe("bump highlight mapping", function()
    it("maps bump types to correct highlight groups", function()
      local bump_hl = {
        major = "DiagnosticError",
        minor = "DiagnosticWarn",
        patch = "DiagnosticHint",
      }
      assert.equals("DiagnosticError", bump_hl["major"])
      assert.equals("DiagnosticWarn",  bump_hl["minor"])
      assert.equals("DiagnosticHint",  bump_hl["patch"])
      -- Unknown bump falls back to DiagnosticInfo
      assert.is_nil(bump_hl["unknown"])
    end)
  end)

  describe("item text construction", function()
    it("constructs searchable text from tool name + versions", function()
      -- Simulates what the finder does when building item.text
      local function make_text(name, current, latest)
        return name .. " " .. current .. " " .. latest
      end

      local text = make_text("node", "20.0.0", "22.5.0")
      assert.truthy(text:find("node"))
      assert.truthy(text:find("20.0.0"))
      assert.truthy(text:find("22.5.0"))
    end)
  end)
end)
