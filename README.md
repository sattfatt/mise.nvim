# mise-nvim

A comprehensive Neovim plugin for [mise](https://mise.jdx.dev) — the polyglot dev environment manager.

Deep integration with [snacks.nvim](https://github.com/folke/snacks.nvim) picker for browsing tools, tasks, environments, and more.

## Features

- **Tool Picker** — Browse all installed tools with version info, install/uninstall/upgrade actions
- **Version Picker** — Browse all available versions for any tool, install from picker
- **Task Picker** — Browse and run tasks from `mise.toml`, with preview of scripts
- **Registry Picker** — Search 3000+ tools in the mise registry, install directly
- **Plugin Picker** — Browse installed and remote mise plugins, install/uninstall
- **Config Picker** — Browse the `mise.toml` hierarchy, open files, manage trust
- **Environment Picker** — Browse all env vars set by mise, copy values
- **Outdated Picker** — See tools with newer versions, color-coded by semver bump
- **Statusline API** — `get_tool_version()` and `get_active_tools()` for lualine/heirline
- **Health check** — `:checkhealth mise` for diagnosing issues
- **Commands** — Full set of `:Mise*` commands with tab-completion
- **Autocmds** — Auto-refresh cache on `mise.toml` save, notify on directory changes

## Requirements

- Neovim >= 0.9.0
- [mise](https://mise.jdx.dev) installed and in PATH
- [snacks.nvim](https://github.com/folke/snacks.nvim) with `picker` enabled (for pickers)

## Installation

### lazy.nvim

```lua
{
  "sattfatt/mise.nvim",
  lazy = false,       -- load eagerly for statusline/autocmds
  priority = 100,
  dependencies = {
    "folke/snacks.nvim",
  },
  opts = {},          -- use defaults, or customize (see Configuration)
  keys = {
    { "<leader>mt", "<cmd>MiseTools<cr>",    desc = "Mise Tools" },
    { "<leader>mr", "<cmd>MiseRun<cr>",      desc = "Mise Run Task" },
    { "<leader>mw", "<cmd>MiseWatch<cr>",    desc = "Mise Watch Task" },
    { "<leader>mi", "<cmd>MiseInstall<cr>",  desc = "Mise Install" },
    { "<leader>mu", "<cmd>MiseUpgrade<cr>",  desc = "Mise Upgrade" },
    { "<leader>mo", "<cmd>MiseOutdated<cr>", desc = "Mise Outdated" },
    { "<leader>me", "<cmd>MiseEnv<cr>",      desc = "Mise Env" },
    { "<leader>mc", "<cmd>MiseConfig<cr>",   desc = "Mise Config" },
    { "<leader>mR", "<cmd>MiseRegistry<cr>", desc = "Mise Registry" },
    { "<leader>mp", "<cmd>MisePlugins<cr>",  desc = "Mise Plugins" },
  },
}
```

## Configuration

```lua
require("mise").setup({
  -- Path to mise binary (default: "mise", searches PATH)
  mise_path = "mise",

  -- Where to run mise commands
  -- "cwd"  → vim.fn.getcwd()
  -- "root" → nearest mise.toml (walks up from cwd)
  cwd = "cwd",

  -- Terminal settings for task output
  terminal = {
    split = "horizontal",  -- "horizontal" | "vertical" | "float"
    height = 15,           -- lines (horizontal split)
    width = 80,            -- cols (vertical split)
  },

  -- Autocommand behaviour
  autocmds = {
    watch_config = true,          -- Invalidate cache when mise.toml is saved
    notify_on_dir_change = true,  -- Notify on DirChanged when tools change
  },

  -- Statusline integration
  statusline = {
    icon = " ",
    tools = {},  -- specific tools to show (empty = all active)
  },

  -- Per-picker option overrides (merged into Snacks.picker.pick() opts)
  pickers = {
    tools    = {},
    tasks    = {},
    registry = {},
    versions = {},
    plugins  = {},
    config   = {},
    env      = {},
    outdated = {},
  },

  -- Notification level for success messages
  notify = {
    level = vim.log.levels.INFO,
  },
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:MiseTools` | Browse installed tools |
| `:MiseTasks` | Browse tasks |
| `:MiseRun [TASK]` | Run a task (opens picker if no arg) |
| `:MiseWatch [TASK]` | Watch-run a task (opens picker if no arg) |
| `:MiseInstall [TOOL@VER]` | Install a tool |
| `:MiseUninstall [TOOL@VER]` | Uninstall a tool |
| `:MiseUpgrade [TOOL]` | Upgrade a tool (outdated picker if no arg) |
| `:MiseUse [TOOL@VER]` | Install tool + add to `mise.toml` |
| `:MiseVersions TOOL` | Browse versions for a tool |
| `:MiseRegistry` | Browse the mise registry |
| `:MiseEnv` | Browse environment variables |
| `:MiseOutdated` | Show outdated tools |
| `:MiseConfig` | Browse config files |
| `:MisePlugins` | Browse plugins |
| `:MiseTrust [FILE]` | Trust a config file |
| `:MiseWhere TOOL` | Show install path (copies to clipboard) |
| `:MiseDoctor` | Run mise doctor |

All commands with optional arguments support tab-completion.

## Picker Keybindings

### Tools Picker (`:MiseTools`)
| Key | Action |
|-----|--------|
| `<CR>` | Open source config file |
| `<C-i>` | Install tool version |
| `<C-x>` | Uninstall tool version |
| `<C-u>` | Upgrade tool |
| `<C-v>` | Browse versions for this tool |
| `<C-y>` | Yank `tool@version` |

### Tasks Picker (`:MiseTasks`, `:MiseRun`)
| Key | Action |
|-----|--------|
| `<CR>` | Run task in terminal |
| `<C-r>` | Run task |
| `<C-w>` | Watch-run task |
| `<C-e>` | Edit source file |
| `<C-y>` | Yank task name |
| `<C-d>` | Show task dependencies |

### Registry Picker (`:MiseRegistry`)
| Key | Action |
|-----|--------|
| `<CR>` | Install tool at latest |
| `<C-i>` | Install at latest |
| `<C-u>` | Use at latest (add to config) |
| `<C-v>` | Browse versions |
| `<C-y>` | Yank tool name |

### Versions Picker (`:MiseVersions TOOL`)
| Key | Action |
|-----|--------|
| `<CR>` | `mise use TOOL@VERSION` (adds to config) |
| `<C-i>` | `mise install TOOL@VERSION` (install only) |
| `<C-y>` | Yank `tool@version` |

### Outdated Picker (`:MiseOutdated`)
| Key | Action |
|-----|--------|
| `<CR>` | Upgrade selected tool |
| `<C-a>` | Upgrade all tools |
| `<C-e>` | Edit source config |
| `<C-y>` | Yank upgrade command |

### Plugins Picker (`:MisePlugins`)
| Key | Action |
|-----|--------|
| `<CR>` | Install (remote) / Update (installed) |
| `<C-i>` | Install plugin |
| `<C-x>` | Uninstall plugin |
| `<C-u>` | Update plugin |
| `<C-t>` | Toggle installed/remote mode |
| `<C-y>` | Yank plugin name |

### Config Picker (`:MiseConfig`)
| Key | Action |
|-----|--------|
| `<CR>` | Open config file in editor |
| `<C-t>` | Trust config file |
| `<C-u>` | Revoke trust |

### Env Picker (`:MiseEnv`)
| Key | Action |
|-----|--------|
| `<CR>` | Copy value to clipboard |
| `<C-y>` | Copy `KEY=VALUE` to clipboard |
| `<C-e>` | Open mise.toml at `[env]` section |

## Statusline Integration

```lua
-- lualine component for current node version
{
  function()
    local mise = require("mise")
    local ver = mise.get_tool_version("node")
    return ver and (" " .. ver) or ""
  end,
  cond = function()
    return require("mise.util").check_mise()
  end,
}

-- Show all active tools
{
  function()
    local tools = require("mise").get_active_tools()
    if #tools == 0 then return "" end
    return " " .. table.concat(
      vim.tbl_map(function(t) return t.name .. ":" .. t.version end, tools),
      " | "
    )
  end,
}
```

`get_tool_version()` is synchronous and cached — safe to call from statusline. The cache is invalidated automatically when any `mise.toml` file is saved.

## Events

The plugin emits a `User MiseConfigChanged` event when a `mise.toml` file is written.

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "MiseConfigChanged",
  callback = function(ev)
    -- ev.data.file contains the changed file path
    print("mise config changed: " .. ev.data.file)
  end,
})
```

## Health Check

```
:checkhealth mise
```

Verifies: Neovim version, mise binary, `mise doctor` output, snacks.nvim availability, and `vim.system()` support.
