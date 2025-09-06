# Contributing

Thanks for considering a contribution to codex.nvim! This guide outlines commit message conventions and pull request expectations, plus a few tips for a smooth review.

## Commit Message Conventions

Observed in this repo’s history:

- Scope prefix: use a concise component or area followed by a colon.
  - Examples: `refactor: …`, `alerts: …`, `config,utils,docs: …`
- Imperative, lower‑case verbs: start with an action.
  - Examples: `add`, `remove`, `update`, `refactor`, `simplify`, `fix`
- Keep subjects brief; add detail in the body if needed.
- Multiple scopes allowed with commas when changes span modules.

Examples from history:

- `refactor: enhance macOS notification handling with terminal-notifier support`
- `alerts: add idle-based completion notifications with macOS system sound; add de-dup + one-shot idle monitor; docs: update README and add README.zh-CN`
- `config,utils,docs: remove ask_for_approval option`

## Pull Request Guidelines

- Description: clearly state the problem and the approach taken.
- Reproduction: provide steps or a minimal config when fixing a bug.
- Visuals/Logs: include screenshots or Neovim `:messages` output when UI behavior changes.
- Linked issues: reference related issues or discussions when applicable.
- User-facing changes: update `README.md` (and `README.zh-CN.md`) for new options or commands.
- Tests: run `make test` locally. Keep tests fast and deterministic; add tests following the `tests/run_*.lua` pattern when appropriate.
- Style: Lua 5.1, 2-space indents, no tabs. Prefer `vim.api`, `vim.fn`, and schedule UI calls via `vim.schedule` for safety.
- Logging: keep logs concise; use `logger.[error|warn|info|debug|trace]` with a component tag.

## Notifications (FYI for contributors)

- macOS: prefers `terminal-notifier`, falls back to `osascript`, then `vim.notify`.
- Idle completion detection: hashes tail content to decide idle; one-shot per run.
- Cancellation suppression: if tail contains a cancel marker (e.g., `Request interrupted by user`, `Canceled`, `取消`), the idle notifier does not send a completion notification. Markers are configurable via `notification.idle.cancel_markers`.

## Development Tips

- Set `CODEX_LOG_LEVEL=debug` or `setup({ log_level = 'debug' })` for verbose logs.
- Enable `log_to_file = true` to write logs to `$TMPDIR/codex.nvim.log` and inspect behavior.
- Local dev loop: open this repo in Neovim and use `:luafile %` while editing; see `Makefile` for test shortcuts.

We appreciate your contributions! 🙌

