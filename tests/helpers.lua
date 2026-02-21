--- Shared test helpers for mise-nvim tests
local M = {}

-- Capture all vim.notify calls during a test
function M.capture_notifications()
  local captured = {} ---@type {msg: string, level: number, opts: table}[]
  local original = vim.notify
  vim.notify = function(msg, level, opts)
    table.insert(captured, { msg = msg, level = level or 0, opts = opts or {} })
  end
  return captured, function()
    vim.notify = original
  end
end

-- Stub vim.system to return a fake result.
-- Returns a restore function.
---@param stdout string
---@param stderr string
---@param code number
---@return fun() restore
function M.stub_vim_system(stdout, stderr, code)
  local original = vim.system
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.system = function(cmd, opts, on_exit)
    local result = {
      stdout = stdout,
      stderr = stderr,
      code   = code,
      wait   = function() return { stdout = stdout, stderr = stderr, code = code } end,
    }
    if on_exit then
      -- Call asynchronously via vim.schedule to mimic real vim.system
      vim.schedule(function()
        on_exit(result)
      end)
      return result
    end
    return result
  end
  return function()
    vim.system = original
  end
end

-- Stub a specific mise command.
-- cmd_pattern: string that must appear in the args (e.g. "ls")
-- If matched, returns the given stdout/code; otherwise falls through to original.
---@param cmd_pattern string
---@param stdout string
---@param code? number
---@return fun() restore
function M.stub_mise_cmd(cmd_pattern, stdout, code)
  code = code or 0
  local original = vim.system
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.system = function(args, opts, on_exit)
    local matched = false
    for _, a in ipairs(args or {}) do
      if type(a) == "string" and a:find(cmd_pattern, 1, true) then
        matched = true
        break
      end
    end
    if matched then
      local result = {
        stdout = stdout,
        stderr = "",
        code   = code,
        wait   = function() return { stdout = stdout, stderr = "", code = code } end,
      }
      if on_exit then
        vim.schedule(function() on_exit(result) end)
        return result
      end
      return result
    end
    return original(args, opts, on_exit)
  end
  return function()
    vim.system = original
  end
end

-- Reset mise plugin state between tests (clears cache and reloads config).
function M.reset_mise()
  -- Clear the mise module cache so require("mise") starts fresh
  package.loaded["mise"] = nil
  package.loaded["mise.config"] = nil
  package.loaded["mise.util"] = nil
  package.loaded["mise.commands"] = nil
  package.loaded["mise.autocmd"] = nil
  package.loaded["mise.health"] = nil
  package.loaded["mise.pickers"] = nil
  package.loaded["mise.pickers.tools"] = nil
  package.loaded["mise.pickers.tasks"] = nil
  package.loaded["mise.pickers.config"] = nil
  package.loaded["mise.pickers.env"] = nil
  package.loaded["mise.pickers.outdated"] = nil
  package.loaded["mise.pickers.registry"] = nil
  package.loaded["mise.pickers.versions"] = nil
  package.loaded["mise.pickers.plugins"] = nil
end

-- Wait for vim.schedule callbacks to flush (for async tests).
-- Works by scheduling a callback and coroutine-yielding until it fires.
function M.wait_for_schedule()
  local co = coroutine.running()
  if co then
    vim.schedule(function()
      coroutine.resume(co)
    end)
    coroutine.yield()
  else
    -- Fallback: run the event loop briefly
    vim.wait(50)
  end
end

-- Build a fake mise ls --json output (table → JSON string).
---@param tools table  e.g. { node = {{version="20.0.0", active=true, installed=true}} }
---@return string
function M.fake_ls_json(tools)
  return vim.json.encode(tools)
end

-- Build a fake mise tasks ls --json output.
---@param tasks table[]
---@return string
function M.fake_tasks_json(tasks)
  return vim.json.encode(tasks)
end

-- Build a fake mise outdated --json output.
---@param outdated table  e.g. { node = {name="node", current="20.0.0", latest="22.0.0", bump="major"} }
---@return string
function M.fake_outdated_json(outdated)
  return vim.json.encode(outdated)
end

return M
