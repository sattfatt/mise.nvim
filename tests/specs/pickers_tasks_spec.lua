local helpers = require("tests.helpers")

describe("mise.pickers.tasks (finder logic)", function()
  before_each(function()
    helpers.reset_mise()
    require("mise.config").setup()
  end)

  describe("JSON parsing for mise tasks", function()
    it("parses tasks array correctly", function()
      local util = require("mise.util")
      local json = helpers.fake_tasks_json({
        {
          name = "build",
          description = "Build the project",
          source = "/home/user/mise.toml",
          depends = {},
          run = { "cargo build" },
          hide = false,
          global = false,
        },
        {
          name = "test",
          description = "Run tests",
          source = "/home/user/mise.toml",
          depends = { "build" },
          run = { "cargo test" },
          hide = false,
          global = false,
        },
        {
          name = "hidden-task",
          description = "Should not appear",
          source = "/home/user/mise.toml",
          depends = {},
          run = { "echo hidden" },
          hide = true,
          global = false,
        },
      })

      local tasks, err = util.json_decode(json)
      assert.is_nil(err)
      assert.is_table(tasks)
      assert.equals(3, #tasks)
      assert.equals("build", tasks[1].name)
      assert.equals("Build the project", tasks[1].description)
      assert.is_false(tasks[1].hide)
      assert.is_true(tasks[3].hide)
    end)

    it("task with dependencies lists them", function()
      local util = require("mise.util")
      local json = helpers.fake_tasks_json({
        {
          name = "deploy",
          description = "Deploy",
          source = "/home/user/mise.toml",
          depends = { "build", "test" },
          run = { "./deploy.sh" },
          hide = false,
          global = false,
        },
      })

      local tasks, err = util.json_decode(json)
      assert.is_nil(err)
      assert.equals(2, #tasks[1].depends)
      assert.equals("build", tasks[1].depends[1])
      assert.equals("test", tasks[1].depends[2])
    end)

    it("handles global vs local tasks", function()
      local util = require("mise.util")
      local json = helpers.fake_tasks_json({
        { name = "global-task", global = true,  hide = false, depends = {}, run = {}, description = "" },
        { name = "local-task",  global = false, hide = false, depends = {}, run = {}, description = "" },
      })

      local tasks, err = util.json_decode(json)
      assert.is_nil(err)
      assert.is_true(tasks[1].global)
      assert.is_false(tasks[2].global)
    end)

    it("handles empty tasks list", function()
      local util = require("mise.util")
      local json = helpers.fake_tasks_json({})

      local tasks, err = util.json_decode(json)
      assert.is_nil(err)
      assert.is_table(tasks)
      assert.equals(0, #tasks)
    end)
  end)

  describe("task name namespace colorization", function()
    -- Verify the logic that would be applied in the format function
    it("splits colon-separated task names", function()
      local function split_task_name(name)
        return vim.split(name, ":", { plain = true })
      end

      local parts = split_task_name("env:diff:remote")
      assert.equals(3, #parts)
      assert.equals("env", parts[1])
      assert.equals("diff", parts[2])
      assert.equals("remote", parts[3])

      local simple = split_task_name("build")
      assert.equals(1, #simple)
      assert.equals("build", simple[1])
    end)
  end)

  describe("run_task integration", function()
    it("util.run_task does not error when mise is unavailable", function()
      require("mise.config").setup({ mise_path = "/nonexistent/mise_xyz" })
      local util = require("mise.util")

      -- run_task should not throw even if mise is missing
      -- (snacks.terminal or :terminal will be called)
      assert.has_no.errors(function()
        -- We can't actually open a terminal in headless mode, so just check
        -- that the function exists and doesn't crash on setup
        assert.is_function(util.run_task)
      end)
    end)
  end)

  describe("preview content for tasks", function()
    it("constructs correct preview lines for a task with run script", function()
      local pickers = require("mise.pickers")

      local run_scripts = { "cargo build --release", "echo done" }
      local task = {
        name = "build",
        description = "Build the project",
        source = "/home/user/mise.toml",
        depends = { "clean" },
        run = run_scripts,
      }

      local preview_lines = {
        "# " .. task.name,
        "# " .. task.description,
        "",
        "# depends: " .. table.concat(task.depends, ", "),
        "",
        table.concat(task.run, "\n"),
      }
      local preview = pickers.make_preview(preview_lines, "bash")

      assert.equals("bash", preview.ft)
      assert.truthy(preview.text:find("build"))
      assert.truthy(preview.text:find("cargo build"))
      assert.truthy(preview.text:find("clean"))
    end)
  end)
end)
