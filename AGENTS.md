# Repository Guidelines

## Project Structure & Module Organization
- `lua/codex/`: Core plugin modules (`init.lua`, `config.lua`, `utils.lua`, `terminal.lua`, `logger.lua`). Public API is in `init.lua` (`setup`, `open`, `toggle`).
- `plugin/codex.lua`: Auto‑bootstrap of commands on startup.
- `tests/`: Headless sanity tests (`minimal_init.lua`, `run_basic.lua`, `run_commands.lua`).
- `Makefile`: Convenience targets for running tests.

## Build, Test, and Development Commands
- `make test`: Runs headless Neovim tests (basic + commands). Equivalent to:
  - `nvim --headless -u tests/minimal_init.lua +"lua dofile(\"tests/run_basic.lua\")"`
  - `nvim --headless -u tests/minimal_init.lua +"lua dofile(\"tests/run_commands.lua\")"`
- Local dev: open this repo in Neovim and run `:luafile %` while editing.
- Real runs require Codex CLI on PATH (e.g., `brew install codex` or `npm i -g @openai/codex`).

## Coding Style & Naming Conventions
- Language: Lua 5.1 (Neovim runtime). Indent 2 spaces; no tabs.
- Files: snake_case names in `lua/codex/` (e.g., `utils.lua`).
- Exports: return module table `M`; public functions use verb names (`setup`, `open`, `exec`).
- Prefer `vim.api`, `vim.fn`, and scheduled UI calls (`vim.schedule`) for safety.
- Keep logs concise; use `logger.[error|warn|info|debug|trace]` with a component tag.

## Testing Guidelines
- Tests are headless and self‑contained; no external Codex binary required (tests stub with `echo`).
- Add new tests under `tests/`, following the current pattern (`run_*.lua`).
- Run tests via `make test`. Keep tests fast (<1s) and deterministic.

## Commit & Pull Request Guidelines
- Commits: imperative mood, scoped when useful. Example: `terminal: reuse buffer when split exists`.
- PRs: include a clear description, reproduction steps, and screenshots or logs (Neovim messages) when UI behavior changes.
- Link related issues; update `README.md` for user‑visible options or commands.

## Configuration & Logging
- Key options in `config.lua` (e.g., `bin`, `model`, `cwd_provider`, `terminal.*`). Example:
  - `require("codex").setup({ bin = "codex", terminal = { direction = "vertical", size = 0.4 } })`
- Set log level via `CODEX_LOG_LEVEL=debug` or `setup({ log_level = "debug" })` during development.
