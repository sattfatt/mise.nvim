local M = {}

local _has_snacks = nil ---@type boolean?
local _mise_bin = nil  ---@type string?

--- Return the resolved mise binary path.
--- Resolves the configured path (default "mise") to a full absolute path
--- so that vim.system / uv.spawn can find it even when Neovim's PATH
--- doesn't include the shell-function wrappers (e.g. GUI launch).
---@return string
function M.mise_bin()
  if _mise_bin then
    return _mise_bin
  end
  local configured = require("mise.config").get().mise_path
  -- If already absolute, use as-is
  if configured:sub(1, 1) == "/" then
    _mise_bin = configured
    return _mise_bin
  end
  -- Try to resolve via exepath (searches $PATH as Neovim sees it)
  local resolved = vim.fn.exepath(configured)
  if resolved ~= "" then
    _mise_bin = resolved
    return _mise_bin
  end
  -- Fallback: common install locations
  local fallbacks = {
    vim.fn.expand("~/.local/bin/mise"),
    "/opt/homebrew/bin/mise",
    "/usr/local/bin/mise",
    "/usr/bin/mise",
  }
  for _, path in ipairs(fallbacks) do
    if vim.fn.executable(path) == 1 then
      _mise_bin = path
      return _mise_bin
    end
  end
  -- Last resort: return configured name and let it fail naturally
  _mise_bin = configured
  return _mise_bin
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

--- Find the best anchor directory for resolving mise config.
--- The current buffer may be a picker/terminal with no file path,
--- so we walk listed buffers (most-recently-created first) to find
--- a real file buffer to anchor from.
---@return string
local function _best_anchor()
  -- Current buffer first
  local cur = vim.api.nvim_buf_get_name(0)
  if cur ~= "" and vim.fn.filereadable(cur) == 1 then
    return vim.fn.fnamemodify(cur, ":h")
  end

  -- Walk all listed buffers in reverse (highest bufnr = most recently created)
  local bufs = vim.api.nvim_list_bufs()
  for i = #bufs, 1, -1 do
    local b = bufs[i]
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted then
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= "" and vim.fn.filereadable(name) == 1 then
        return vim.fn.fnamemodify(name, ":h")
      end
    end
  end

  -- Last resort: window-local cwd
  return vim.fn.getcwd(0)
end

--- Return the effective cwd for mise commands.
--- Anchors from the nearest real file buffer so mise finds the correct
--- mise.toml even when Neovim's global cwd differs from the edited project
--- or when the active buffer is a picker/terminal with no file path.
---@return string
function M.cwd()
  local anchor = _best_anchor()

  local found = vim.fs.find(
    { "mise.toml", ".mise.toml", "mise.local.toml", ".tool-versions" },
    { upward = true, path = anchor }
  )
  if found[1] then
    return vim.fn.fnamemodify(found[1], ":h")
  end

  return anchor
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
