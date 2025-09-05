# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

codex.nvim is a minimal Neovim plugin that provides integration with the OpenAI Codex CLI. It opens Codex TUI in terminal splits and runs non-interactive `codex exec` commands with prompts from Neovim, including visual selections.

## Build and Test Commands

```bash
# Run all tests
make test

# Individual test files can be run manually:
nvim --headless -u tests/minimal_init.lua +"lua dofile('tests/run_basic.lua')"
nvim --headless -u tests/minimal_init.lua +"lua dofile('tests/run_commands.lua')"

# Tests run headless with nvim and don't require the actual Codex CLI
# Tests are in tests/ directory with minimal_init.lua, run_basic.lua, and run_commands.lua
```

## Architecture

### Core Module Structure

The plugin follows a modular architecture with clear separation of concerns:

- **lua/codex/init.lua** - Main entry point and API (lines 1-80+)
  - `setup()` - Initialize plugin with user configuration
  - `open()` - Open Codex TUI with optional prompt
  - `toggle()` - Smart toggle: opens terminal if none exists, otherwise toggles visibility
  - Creates user commands: `:CodexOpen`, `:CodexToggle`

- **lua/codex/config.lua** - Configuration management (lines 1-50)
  - Default settings for binary path, model, terminal behavior
  - Supports `cwd_provider`: 'git' (repo root), 'cwd' (current dir), 'file' (file's directory)
  - Terminal configuration: direction, size, position, provider (native/snacks/auto)
  - Handles backward compatibility aliases

- **lua/codex/terminal.lua** - Terminal split management (lines 1-300+)
  - Manages terminal buffer lifecycle and reuse
  - Supports multiple terminal providers: native Neovim, Snacks.nvim (if available)
  - Handles headless mode for testing (runs as background jobs)
  - Smart split sizing with fractional support (0-1 as percentage)
  - `run()` - Main function to execute commands in terminal (line 175)
  - `simple_toggle()` - Toggle terminal visibility with improved state checking (line 137)

- **lua/codex/utils.lua** - Utility functions (lines 1-75)
  - `get_cwd()` - Determine working directory based on provider setting
  - `build_cmd()` - Build command array with model, approval flags, extra args
  - Git repository detection and root finding

- **lua/codex/logger.lua** - Logging system
  - Log levels: trace, debug, info, warn, error
  - Configurable via `log_level` option or `CODEX_LOG_LEVEL` env var

### Key Design Patterns

1. **State Management**: Single state object in init.lua tracks configuration and terminal state
2. **Terminal Reuse**: Reuses terminal buffers by default to avoid multiple windows
3. **Provider Abstraction**: Supports multiple terminal providers with fallback logic
4. **Command Building**: Central command construction with consistent flag handling
5. **Working Directory Logic**: Smart CWD detection prioritizing git root, with fallbacks
6. **Environment Sanitization**: All environment variables are converted to strings and nil values filtered out

### Integration Points

- **Codex CLI**: Expects `codex` binary on PATH (or custom path via `bin` config)
- **Git**: Optional git integration for project root detection via `git rev-parse`
- **Snacks.nvim**: Optional enhanced terminal provider if available (auto-detected)
- **Neovim APIs**: Uses native terminal, buffer, and window management APIs
- **Headless Support**: Detects headless mode and runs commands as background jobs

### Terminal Provider System

The plugin supports multiple terminal providers with fallback:
- `native`: Pure Neovim terminal splits
- `snacks`: Uses folke/snacks.nvim if available
- `auto`: Detects Snacks availability and falls back gracefully

Size calculation supports both absolute values (>= 1) and fractional values (0 < size < 1) as percentages of the current window.

## Common Development Tasks

When modifying the plugin:

1. **Adding new commands**: Update `M._create_commands()` in init.lua (around line 90+)
2. **Terminal behavior**: Modify terminal.lua, especially `M.run()` at line 175+ and `M.simple_toggle()` at line 137+
3. **Configuration options**: Add to `M.defaults` in config.lua:3 and handle in `M.apply()`
4. **Command building**: Update `build_cmd()` in utils.lua:42 for new CLI flags
5. **Logging**: Use the logger module for debugging - levels: trace, debug, info, warn, error

### Testing Strategy

The test suite uses headless Neovim and mocks the Codex CLI (using `echo` instead):
- `tests/minimal_init.lua` - Sets up minimal environment and silences UI prompts
- `tests/run_basic.lua` - Tests core functionality 
- `tests/run_commands.lua` - Tests user commands
- Tests validate plugin behavior without requiring actual Codex CLI installation