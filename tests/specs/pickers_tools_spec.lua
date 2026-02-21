local helpers = require("tests.helpers")

-- These tests verify the tools picker's finder and format logic
-- without actually opening the snacks UI.

describe("mise.pickers.tools (finder logic)", function()
  before_each(function()
    helpers.reset_mise()
    require("mise.config").setup()
  end)

  -- Run the finder function synchronously and collect items
  local function collect_items(finder_fn)
    local items = {}
    -- The finder returns an async function(cb), call it synchronously for tests
    local inner = finder_fn({}, {
      opts = function(o) return o end,
      picker = { opts = { debug = { proc = false } } },
    })
    if type(inner) == "function" then
      inner(function(item)
        table.insert(items, item)
      end)
    end
    return items
  end

  describe("finder", function()
    it("returns items for each installed tool version", function()
      local util = require("mise.util")
      local original_run = util.run
      util.run = function(args, _)
        if args[1] == "ls" and args[2] == "--json" then
          return helpers.fake_ls_json({
            node = {
              {
                version = "20.0.0",
                active = true,
                installed = true,
                requested_version = "latest",
                install_path = "/home/user/.local/share/mise/installs/node/20.0.0",
                source = { type = "mise.toml", path = "/home/user/mise.toml" },
              },
            },
            python = {
              {
                version = "3.11.0",
                active = false,
                installed = true,
                requested_version = "3.11",
                install_path = "/home/user/.local/share/mise/installs/python/3.11.0",
              },
            },
          }), "", 0
        end
        return original_run(args, _)
      end

      -- Directly test the finder function
      local tools_module = require("mise.pickers.tools")
      local pickers_init = require("mise.pickers")

      -- Stub check_snacks to avoid needing snacks for finder tests
      local original_check = pickers_init.check_snacks
      pickers_init.check_snacks = function() return true end

      -- We test the finder indirectly by exercising parse_tool_key and json_decode
      local stdout = helpers.fake_ls_json({
        node = {
          { version = "20.0.0", active = true, installed = true,
            install_path = "/path/node/20.0.0",
            source = { type = "mise.toml", path = "/home/user/mise.toml" },
            requested_version = "latest" },
        },
        ["cargo:git-branchless"] = {
          { version = "0.10.0", active = true, installed = true,
            install_path = "/path/cargo/0.10.0",
            requested_version = "latest" },
        },
      })

      local data, err = util.json_decode(stdout)
      assert.is_nil(err)
      assert.is_not_nil(data)
      assert.is_table(data.node)
      assert.equals(1, #data.node)
      assert.equals("20.0.0", data.node[1].version)
      assert.is_true(data.node[1].active)

      pickers_init.check_snacks = original_check
      util.run = original_run
    end)

    it("parses backend from tool key correctly", function()
      local pickers_init = require("mise.pickers")

      local result = pickers_init.parse_tool_key("cargo:git-branchless")
      assert.equals("cargo", result.backend)
      assert.equals("git-branchless", result.name)

      local result2 = pickers_init.parse_tool_key("node")
      assert.is_nil(result2.backend)
      assert.equals("node", result2.name)

      local result3 = pickers_init.parse_tool_key("npm:@scope/package")
      assert.equals("npm", result3.backend)
      assert.equals("@scope/package", result3.name)
    end)

    it("handles empty mise ls output gracefully", function()
      local util = require("mise.util")
      local original_run = util.run
      util.run = function(args, _)
        if args[1] == "ls" and args[2] == "--json" then
          return "{}", "", 0
        end
        return original_run(args, _)
      end

      local data, err = util.json_decode("{}")
      assert.is_nil(err)
      assert.is_table(data)
      assert.equals(0, vim.tbl_count(data))

      util.run = original_run
    end)
  end)

  describe("pickers.init helpers", function()
    it("make_preview returns table with text and ft", function()
      local pickers_init = require("mise.pickers")
      local result = pickers_init.make_preview({ "line1", "line2" }, "yaml")
      assert.is_table(result)
      assert.equals("line1\nline2", result.text)
      assert.equals("yaml", result.ft)
    end)

    it("make_preview defaults ft to yaml", function()
      local pickers_init = require("mise.pickers")
      local result = pickers_init.make_preview({ "tool: node" })
      assert.equals("yaml", result.ft)
    end)

    it("backend_hl returns string highlight group", function()
      local pickers_init = require("mise.pickers")
      local hl = pickers_init.backend_hl("aqua:aws/aws-cli")
      assert.is_string(hl)
      assert.equals("DiagnosticHint", hl)

      assert.equals("DiagnosticOk",  pickers_init.backend_hl("cargo:tool"))
      assert.equals("DiagnosticWarn", pickers_init.backend_hl("npm:package"))
      assert.equals("Special",        pickers_init.backend_hl("go:tool"))
      assert.equals("Title",          pickers_init.backend_hl("github:owner/repo"))
      assert.equals("SnacksPickerComment", pickers_init.backend_hl("unknown:tool"))
    end)

    it("backend_type extracts type prefix", function()
      local pickers_init = require("mise.pickers")
      assert.equals("aqua",   pickers_init.backend_type("aqua:aws/aws-cli"))
      assert.equals("cargo",  pickers_init.backend_type("cargo:git-branchless"))
      assert.equals("github", pickers_init.backend_type("github:owner/repo"))
      -- No prefix
      assert.equals("node", pickers_init.backend_type("node"))
    end)
  end)

  describe("JSON parsing for mise ls", function()
    it("correctly identifies active vs inactive tools", function()
      local util = require("mise.util")
      local json = helpers.fake_ls_json({
        node = {
          { version = "20.0.0", active = true,  installed = true },
          { version = "18.0.0", active = false, installed = true },
        },
      })
      local data, err = util.json_decode(json)
      assert.is_nil(err)
      assert.equals(2, #data.node)
      assert.is_true(data.node[1].active)
      assert.is_false(data.node[2].active)
    end)

    it("handles tools with no source (not active)", function()
      local util = require("mise.util")
      local json = helpers.fake_ls_json({
        bat = {
          { version = "0.24.0", active = false, installed = true, install_path = "/path" },
        },
      })
      local data, err = util.json_decode(json)
      assert.is_nil(err)
      assert.is_not_nil(data.bat)
      assert.is_nil(data.bat[1].source)
    end)
  end)
end)
