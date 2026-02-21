local helpers = require("tests.helpers")

describe("mise.pickers.env (finder logic)", function()
  before_each(function()
    helpers.reset_mise()
    require("mise.config").setup()
  end)

  describe("JSON parsing for mise env", function()
    it("parses flat env JSON object", function()
      local util = require("mise.util")
      local env_data = {
        NODE_VERSION = "20.0.0",
        PATH = "/home/user/.local/share/mise/installs/node/20.0.0/bin:/usr/local/bin:/usr/bin",
        GOPATH = "/home/user/go",
        VIRTUAL_ENV = "/home/user/project/.venv",
      }
      local json = vim.json.encode(env_data)
      local data, err = util.json_decode(json)

      assert.is_nil(err)
      assert.is_table(data)
      assert.equals("20.0.0", data.NODE_VERSION)
      assert.is_string(data.PATH)
      assert.truthy(data.PATH:find("/usr/bin"))
    end)

    it("sorts keys alphabetically", function()
      local keys = { "ZEBRA", "APPLE", "MANGO", "BANANA" }
      table.sort(keys)
      assert.equals("APPLE",  keys[1])
      assert.equals("BANANA", keys[2])
      assert.equals("MANGO",  keys[3])
      assert.equals("ZEBRA",  keys[4])
    end)
  end)

  describe("PATH special handling", function()
    it("splits PATH on colon for preview", function()
      local path_val = "/a/b/c:/d/e/f:/g/h/i"
      local paths = vim.split(path_val, ":", { plain = true })
      assert.equals(3, #paths)
      assert.equals("/a/b/c", paths[1])
      assert.equals("/d/e/f", paths[2])
      assert.equals("/g/h/i", paths[3])
    end)

    it("builds PATH preview lines correctly", function()
      local pickers = require("mise.pickers")
      local key = "PATH"
      local val = "/usr/bin:/usr/local/bin"
      local paths = vim.split(val, ":", { plain = true })

      local preview_lines = { key .. "=" }
      for _, p in ipairs(paths) do
        preview_lines[#preview_lines + 1] = "  " .. p
      end

      local preview = pickers.make_preview(preview_lines, "bash")
      assert.equals("bash", preview.ft)
      assert.truthy(preview.text:find("PATH="))
      assert.truthy(preview.text:find("/usr/bin"))
      assert.truthy(preview.text:find("/usr/local/bin"))
    end)
  end)

  describe("value display truncation", function()
    it("truncates values longer than 80 chars", function()
      -- Simulate what the format function does
      local long_val = string.rep("a", 100)
      local display_val = long_val
      if #display_val > 80 then
        display_val = display_val:sub(1, 77) .. "..."
      end
      assert.equals(80, #display_val)
      assert.truthy(display_val:find("%.%.%.$"))
    end)

    it("does not truncate short values", function()
      local short_val = "20.0.0"
      local display_val = short_val
      if #display_val > 80 then
        display_val = display_val:sub(1, 77) .. "..."
      end
      assert.equals("20.0.0", display_val)
    end)
  end)
end)
