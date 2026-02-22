--- Shared utilities for all mise pickers
local M = {}

--- Build a preview table for any mise entity.
---@param lines string[]
---@param ft? string
---@return table
function M.make_preview(lines, ft)
  return {
    text = table.concat(lines, "\n"),
    ft = ft or "yaml",
  }
end

--- Determine highlight group for a backend type string.
--- e.g. "aqua:aws/aws-cli" → "DiagnosticHint"
---@param backend string
---@return string
function M.backend_hl(backend)
  local btype = backend:match("^(%w+):")
  local hl_map = {
    aqua   = "DiagnosticHint",
    asdf   = "DiagnosticInfo",
    cargo  = "DiagnosticOk",
    npm    = "DiagnosticWarn",
    go     = "Special",
    pipx   = "Identifier",
    github = "Title",
    gitlab = "Title",
    core   = "SnacksPickerLabel",
    vfox   = "Function",
    ubi    = "Constant",
  }
  return hl_map[btype] or "SnacksPickerComment"
end

--- Extract just the backend type label from a backend string.
--- "aqua:aws/aws-cli" → "aqua"
---@param backend string
---@return string
function M.backend_type(backend)
  return backend:match("^(%w+):") or backend
end

--- Check if snacks is available and warn if not.
--- Returns false if pickers cannot be shown.
---@return boolean
function M.check_snacks()
  local util = require("mise.util")
  if not util.has_snacks() then
    util.notify(
      "snacks.nvim is required for pickers. Install folke/snacks.nvim.",
      vim.log.levels.WARN
    )
    return false
  end
  return true
end

--- Close a picker and run an async mise command, notifying on completion.
---@param picker table snacks.Picker
---@param args string[]
---@param success_msg string
---@param error_msg? string
---@param on_success? fun()
function M.close_and_run(picker, args, success_msg, error_msg, on_success)
  picker:close()
  local util = require("mise.util")
  util.run_async(args, function(_, stderr, code)
    if code == 0 then
      util.notify(success_msg)
      require("mise").invalidate_cache()
      if on_success then
        vim.schedule(on_success)
      end
    else
      util.notify(
        (error_msg or "Command failed") .. ": " .. vim.trim(stderr),
        vim.log.levels.ERROR
      )
    end
  end)
end

--- Build a confirm dialog using vim.ui.input (works without snacks).
---@param prompt string
---@param on_confirm fun()
function M.confirm(prompt, on_confirm)
  -- Try snacks input first, fall back to vim.ui.input
  local ok, Snacks = pcall(require, "snacks")
  if ok and Snacks.input then
    Snacks.input({ prompt = prompt .. " (y/N): " }, function(val)
      if val and (val:lower() == "y" or val:lower() == "yes") then
        on_confirm()
      end
    end)
  else
    vim.ui.input({ prompt = prompt .. " (y/N): " }, function(val)
      if val and (val:lower() == "y" or val:lower() == "yes") then
        on_confirm()
      end
    end)
  end
end

--- Build a compact highlighted footer from a keys table.
--- Pass the same keys table you give to win.input.keys.
--- Returns a {text, hl}[] array suitable for win.input.footer.
---
--- Keys are sorted, <CR> is always shown first (as "↵"), then the rest.
--- Example output:  ↵ Run   ^r Run   ^w Watch   ^e Edit   ^y Yank
---
---@param keys table<string, table>  e.g. { ["<CR>"] = {"action", mode=…, desc="Foo"} }
---@return table  snacks-compatible footer highlights array
function M.make_footer(keys)
  -- Normalise a lhs string to a short human-readable form.
  local function short(lhs)
    lhs = lhs:gsub("<CR>",  "↵")
    lhs = lhs:gsub("<C%-", "^")
    lhs = lhs:gsub(">",    "")
    return lhs
  end

  -- Collect entries: { lhs_short, desc }
  local entries = {}
  for lhs, def in pairs(keys) do
    -- def is { "action_name", mode=…, desc="…" }  (positional + named fields)
    local desc = def.desc or def[1] or lhs
    entries[#entries + 1] = { key = lhs, short = short(lhs), desc = desc }
  end

  -- Sort: <CR> first, then alphabetically by lhs
  table.sort(entries, function(a, b)
    if a.key == "<CR>" then return true end
    if b.key == "<CR>" then return false end
    return a.key < b.key
  end)

  local footer = {}
  for i, e in ipairs(entries) do
    if i > 1 then
      footer[#footer + 1] = { "  ", "SnacksFooter" }
    end
    footer[#footer + 1] = { " " .. e.short .. " ", "SnacksFooterKey" }
    footer[#footer + 1] = { e.desc,                "SnacksFooterDesc" }
  end
  return footer
end

--- Format a tool name, splitting backend prefix from tool name.
--- "cargo:git-branchless" → { backend = "cargo", name = "git-branchless" }
---@param tool_key string
---@return {backend: string?, name: string}
function M.parse_tool_key(tool_key)
  local backend, name = tool_key:match("^([^:]+):(.+)$")
  if backend and name then
    return { backend = backend, name = name }
  end
  return { backend = nil, name = tool_key }
end

return M
