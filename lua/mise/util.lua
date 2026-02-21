local M = {}

local _has_snacks = nil ---@type boolean?

--- Return the mise binary path from config.
---@return string
function M.mise_bin()
  return require("mise.config").get().mise_path
end

--- Check if mise binary exists and is executable.
---@return boolean
function M.check_mise()
  return vim.fn.executable(M.mise_bin()) == 1
end

--- Check if snacks.nvim is available (result is cached).
---@return boolean
function M.has_snacks()
  if _has_snacks == nil then
    _has_snacks = pcall(require, "snacks")
  end
  return _has_snacks
end

--- Return the effective cwd for mise commands.
--- Searches up for mise.toml if config.cwd == "root".
---@return string
function M.cwd()
  local cfg = require("mise.config").get()
  if cfg.cwd == "root" then
    local found = vim.fs.find(
      { "mise.toml", ".mise.toml", "mise.local.toml", ".tool-versions" },
      { upward = true, path = vim.fn.getcwd() }
    )
    if found[1] then
      return vim.fn.fnamemodify(found[1], ":h")
    end
  end
  return vim.fn.getcwd()
end

--- Notify using vim.notify with mise prefix.
---@param msg string
---@param level? number vim.log.levels.*
function M.notify(msg, level)
  local cfg = require("mise.config").get()
  level = level or cfg.notify.level
  vim.notify(msg, level, { title = "mise" })
end

--- Parse JSON string safely.
---@param str string
---@return table?, string?
function M.json_decode(str)
  local ok, result = pcall(vim.json.decode, str, { luanil = { object = true, array = true } })
  if not ok then
    return nil, result
  end
  return result, nil
end

--- Synchronously run a mise command.
--- Returns stdout, stderr, exit_code.
---@param args string[]
---@param opts? {cwd?: string, env?: table}
---@return string stdout, string stderr, number code
function M.run(args, opts)
  local bin = M.mise_bin()
  local all_args = vim.list_extend({ bin }, args)
  opts = opts or {}

  if vim.fn.has("nvim-0.10.0") == 1 then
    local ok, result = pcall(function()
      return vim.system(all_args, {
        cwd = opts.cwd or M.cwd(),
        env = opts.env,
        text = true,
      }):wait()
    end)
    if not ok then
      -- Binary not found or spawn error
      return "", tostring(result), 127
    end
    return result.stdout or "", result.stderr or "", result.code
  else
    -- Fallback for older Neovim
    local cmd = table.concat(
      vim.tbl_map(function(a) return vim.fn.shellescape(a) end, all_args),
      " "
    )
    local stdout = vim.fn.system(cmd)
    return stdout, "", vim.v.shell_error
  end
end

--- Asynchronously run a mise command.
--- Calls cb(stdout, stderr, code) on completion (scheduled on main thread).
---@param args string[]
---@param cb fun(stdout: string, stderr: string, code: number)
---@param opts? {cwd?: string, env?: table}
function M.run_async(args, cb, opts)
  local bin = M.mise_bin()
  local all_args = vim.list_extend({ bin }, args)
  opts = opts or {}

  if vim.fn.has("nvim-0.10.0") == 1 then
    local stdout_acc = {} ---@type string[]
    local stderr_acc = {} ---@type string[]
    local ok, err = pcall(vim.system, all_args, {
      cwd = opts.cwd or M.cwd(),
      env = opts.env,
      text = true,
      stdout = function(_, data)
        if data then
          table.insert(stdout_acc, data)
        end
      end,
      stderr = function(_, data)
        if data then
          table.insert(stderr_acc, data)
        end
      end,
    }, function(obj)
      vim.schedule(function()
        cb(table.concat(stdout_acc), table.concat(stderr_acc), obj.code)
      end)
    end)
    if not ok then
      -- Binary not found or spawn error — call cb immediately with error code
      vim.schedule(function()
        cb("", tostring(err), 127)
      end)
    end
  else
    -- Fallback: use jobstart
    local stdout_acc = {} ---@type string[]
    local stderr_acc = {} ---@type string[]
    vim.fn.jobstart(all_args, {
      cwd = opts.cwd or M.cwd(),
      on_stdout = function(_, data)
        vim.list_extend(stdout_acc, data)
      end,
      on_stderr = function(_, data)
        vim.list_extend(stderr_acc, data)
      end,
      on_exit = function(_, code)
        vim.schedule(function()
          cb(table.concat(stdout_acc, "\n"), table.concat(stderr_acc, "\n"), code)
        end)
      end,
    })
  end
end

--- Open a terminal split to run a mise task.
--- Uses Snacks.terminal if available, else native :terminal.
---@param task_name string
---@param watch? boolean Use mise watch instead of mise run
function M.run_task(task_name, watch)
  local cmd_name = watch and "watch" or "run"
  local cmd = { M.mise_bin(), cmd_name, task_name }
  local cwd = M.cwd()

  if M.has_snacks() then
    local Snacks = require("snacks")
    if Snacks.terminal then
      Snacks.terminal(cmd, { cwd = cwd })
      return
    end
  end

  -- Fallback: native terminal in a split
  local cfg = require("mise.config").get()
  if cfg.terminal.split == "vertical" then
    vim.cmd("vsplit")
  elseif cfg.terminal.split == "float" then
    vim.cmd("split")
  else
    vim.cmd("split")
    vim.cmd("resize " .. cfg.terminal.height)
  end
  local escaped = vim.tbl_map(function(a)
    return vim.fn.shellescape(a)
  end, cmd)
  vim.cmd("terminal " .. table.concat(escaped, " "))
  vim.cmd("startinsert")
end

return M
