# codex.nvim

Lightweight Neovim integration for OpenAI Codex CLI. Opens the Codex TUI in a terminal split, or runs non‑interactive `codex exec` with prompts from Neovim (including visual selections).

This plugin follows the structure of `base.nvim` and references ideas from `claudecode.nvim`, but is intentionally minimal.

## Requirements

- Codex CLI installed and on PATH: `npm i -g @openai/codex` or `brew install codex`
- Optional: `git` for project root detection

## Quickstart

```lua
require('codex').setup({
  bin = 'codex',          -- path to the codex binary
  model = nil,            -- override model if desired, e.g. 'o4-mini'
  ask_for_approval = false, -- pass `-a/--ask-for-approval`
  cwd_provider = 'git',   -- 'git' | 'cwd' | 'file'
  terminal = {
    direction = 'horizontal', -- 'horizontal' | 'vertical'
    size = 15,                -- split height/width
    reuse = true,             -- reuse terminal buffer if open
  },
})

-- Example mappings
vim.keymap.set('n', '<leader>co', function() require('codex').open() end, { desc = 'Codex: Open TUI' })
vim.keymap.set('n', '<leader>ce', function() require('codex').ask() end, { desc = 'Codex: Ask (exec)' })
vim.keymap.set('v', '<leader>ce', function() require('codex').exec_visual() end, { desc = 'Codex: Exec (visual)' })
```

## Commands

- `:CodexOpen [prompt]` — Open Codex TUI (optionally seeded with an initial prompt)
- `:CodexExec {prompt}` — Non‑interactive run via `codex exec` in a terminal
- `:CodexAsk` — Prompt for input then run `codex exec`
- `:CodexExecVisual` — Use current visual selection as context for `codex exec`

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
