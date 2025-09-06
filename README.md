# codex.nvim

Lightweight Neovim integration for OpenAI Codex CLI. Opens the Codex TUI in a terminal split.

This plugin follows the structure of `base.nvim` and references ideas from `claudecode.nvim`, but is intentionally minimal.

## Requirements

- Codex CLI installed and on PATH: `npm i -g @openai/codex` or `brew install codex`
- Optional: `git` for project root detection

## Quickstart

```lua
require('codex').setup()

-- Example mappings
vim.keymap.set('n', '<leader>co', function() require('codex').open() end, { desc = 'Codex: Open TUI' })
vim.keymap.set('n', '<leader>ct', function() require('codex').toggle() end, { desc = 'Codex: Toggle terminal' })
```

### Logging

- Log Level: `log_level = 'trace'|'debug'|'info'|'warn'|'error'` (case‑insensitive). Also supports `CODEX_LOG_LEVEL` env var.
- Log to File: set `log_to_file = true` to write logs to a fixed tmp file. The file is truncated on every setup so you always get a fresh log for a new debug session.
  - Default path: `$TMPDIR/codex.nvim.log` (uses your OS tmp dir; on macOS/Linux typically `/tmp/codex.nvim.log`).
  - Override path: set `log_file = '/custom/path/codex.nvim.log'` or provide a string value to `log_to_file`.

Example:

```lua
require('codex').setup({
  log_level = 'trace',
  log_to_file = true,           -- writes to $TMPDIR/codex.nvim.log and truncates on setup
  -- log_to_file = '/tmp/codex.nvim.log', -- custom path (also truncates)
})
```

### Terminal Options

- Direction: 'horizontal' (bottom/top split) or 'vertical' (left/right split).
- Size: split height/width.
  - Number >= 1: absolute rows (horizontal) or columns (vertical).
  - 0 < Number < 1: fraction of your current window (not full screen).
    - Example: 0.33 → one-third of the current window.
- Position: 'left' | 'right' | 'top' | 'bottom'. When omitted, respects your `splitright`/`splitbelow` settings.
- Provider: 'native' | 'snacks' | 'auto'.
  - 'native': use Neovim splits.
  - 'snacks': use `folke/snacks.nvim` terminal. Errors if Snacks is missing (falls back in practice, with a warning).
  - 'auto': use Snacks when available, otherwise silently fall back to native.
- Reuse: reuse the previous terminal buffer if present.
- Auto Insert Mode: enter insert mode automatically after opening.
  - When set to false, the terminal opens without taking focus and stays in normal mode (both native and Snacks providers).
- Fix Display Corruption: schedule a `redraw!` after opening to remedy rare artifacts.

### Sizing Examples

```lua
-- Vertical split with 40% of the current window width
require('codex').setup({
  terminal = { direction = 'vertical', size = 0.40 }
})

-- Horizontal split with 12 rows
require('codex').setup({
  terminal = { direction = 'horizontal', size = 12 }
})

-- Explicit side + fraction
require('codex').setup({
  terminal = { direction = 'vertical', position = 'right', size = 0.25 }
})

-- Auto provider: Snacks if installed, else native
require('codex').setup({
  terminal = { provider = 'auto', direction = 'horizontal', size = 0.33 }
})
```

### Behavior Details

- Fractional Size: calculated against the current window before splitting, for both native and Snacks providers.
- Toggle: `:CodexToggle` toggles the most recent Codex terminal (works with both providers).
- Reuse: when enabled, new runs reattach to the existing terminal buffer and start the command again.
- Headless: in headless (no UI) mode, commands run as background jobs without creating splits.
- Compatibility: legacy `split_width_percentage` is accepted as an alias for `terminal.size` when `size` is not set.
- Logging to File: when enabled, the plugin truncates the log file on setup and appends new entries with timestamps; warn/error also go through `vim.notify`.

## Commands

- `:CodexOpen [prompt]` — Open Codex TUI (optionally seeded with an initial prompt)
- `:CodexToggle` — Toggle Codex terminal split

## Snacks Integration

codex.nvim can optionally use folke/snacks.nvim for opening the terminal with its window manager.

- Install and set up `folke/snacks.nvim` in your config.
- Set `terminal.provider = 'snacks'` to always use Snacks, or `terminal.provider = 'auto'` to use Snacks only when it’s available (falls back to native splits).
- `terminal.direction`, `size`, and `position` are respected:
  - `direction = 'horizontal'` uses a bottom/top split; `size` applies to height.
  - `direction = 'vertical'` uses a left/right split; `size` applies to width.
  - `position` can be `'left' | 'right' | 'top' | 'bottom'`. When omitted, your `splitright`/`splitbelow` settings decide the side.
  - When `size` is `< 1`, it’s treated as a fraction of your current window (not the full screen), for both native and Snacks providers.

Example with Snacks:

```lua
require('codex').setup({
  terminal = {
    provider = 'snacks',
    direction = 'vertical',
    size = 0.35,         -- 35% of the current window width
    position = 'right',  -- or 'left', 'bottom', 'top'
  }
})
```

Tip: legacy `split_width_percentage` is still accepted as an alias for `terminal.size` when `size` is not provided.

### Alerts

- Job Exit Alert and Idle Completion Alert: system notification on completion.

```lua
require('codex').setup({
  -- Exactly one of these is recommended for clarity:
  alert_on_idle = true,        -- notify when terminal output becomes idle (job keeps running)
  -- alert_on_exit = true,     -- notify when the job exits

  notification = {
    enabled = true,
    sound = 'Glass',             -- macOS notification sound name
    include_project_path = true, -- include project/cwd in the message
    speak = false,               -- off by default (no TTS)
    backend = 'terminal-notifier', -- prefer terminal-notifier on macOS
    terminal_notifier = {
      ignore_dnd = true,           -- pass -ignoreDnD
      sender = 'com.apple.Terminal',
      group = 'codex.nvim',
      activate = 'com.apple.Terminal',
    },
    -- Voice is only used if speak=true
    -- voice = 'Samantha',

    -- Idle detection tuning (used when alert_on_idle=true)
    idle = {
      check_interval = 1500,     -- ms between checks
      idle_checks = 3,           -- consecutive no-change checks to consider idle
      lines_to_check = 40,       -- how many tail lines to hash
      require_activity = true,   -- require seeing output changes before considering idle
      min_change_ticks = 3,      -- require at least N changes before eligible
    },
  },
})
```

Behavior:
- macOS: prefers `terminal-notifier` for native banner + sound; falls back to `osascript` if available; otherwise uses `vim.notify`.
- Other OS: falls back to `vim.notify` (no system sound).
- Idle alert is one-shot: once notified, the idle monitor stops until you re-run Codex.
- Exit alert is de-duplicated: suppresses repeated success notifications within a short window.
- Idle alert suppression: if the tail content contains cancellation markers (e.g., "Request interrupted by user", "Canceled", "取消"), no notification is sent. Configure via `notification.idle.cancel_markers`.
  - Included by default: "🖐  Tell the model what to do differently" and its plain variant without the emoji.

Idle Parameters Explained:
- `check_interval` (ms): polling interval to sample terminal tail content.
- `idle_checks`: number of consecutive identical samples to consider idle.
- `lines_to_check`: how many tail lines are included in the hash comparison.
- `require_activity`: only consider idle after seeing at least one change.
- `min_change_ticks`: require at least N changes before an idle period can trigger.

Tip: Prefer enabling either `alert_on_idle` or `alert_on_exit` to avoid redundant signals. Internally, duplicate notifications are still suppressed for safety.

Chinese Documentation: see `README.zh-CN.md`.

## Notes

- Root detection defaults to the Git repo root. Override via `cwd_provider = 'cwd'` or `'file'`.
- Environment variables and extra args can be passed via `env` and `extra_args` in setup.
- For Codex CLI usage and flags, see: https://github.com/openai/codex (README and docs)

## Testing

- Requirements: `nvim` available on PATH.
- Tests run headless and do not require the real Codex binary (they use `echo`).

Run all tests:

```bash
make test
```

## Troubleshooting

- Error: `Invalid argument: env` when using Snacks provider
  - Cause: some environments or older Neovim builds do not accept an empty `env` option through terminal APIs.
  - Fix: codex.nvim now omits `env` when empty and sanitizes values to strings. If you explicitly set `env`, ensure it is a table of string→string pairs. Consider upgrading Neovim if the issue persists.
