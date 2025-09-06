local M = {}

M.defaults = {
  bin = "codex",           -- path to Codex CLI
  model = nil,              -- optional model override
  extra_args = {},          -- additional args array
  env = {},                 -- environment overrides
  cwd_provider = 'git',     -- 'git' | 'cwd' | 'file'
  log_level = (vim.env.CODEX_LOG_LEVEL or 'info'), -- trace|debug|info|warn|error
  log_to_file = false,      -- true|string: write logs to a fixed tmp file (or custom path)
  log_file = nil,           -- custom log file path; defaults to $TMPDIR/codex.nvim.log when log_to_file=true
  -- Alerts/Notifications
  -- When enabled, show a notification when the Codex terminal job exits
  alert_on_exit = false,
  -- When enabled, monitor terminal output and notify on idle (task completion without exiting)
  alert_on_idle = false,
  -- System notification options (macOS supported via osascript). Used when alert_on_exit=true.
  notification = {
    enabled = true,                -- master enable for system notifications
    sound = 'Glass',               -- macOS notification sound name
    title_prefix = 'codex.nvim',   -- title of the notification
    include_project_path = false,  -- include cwd/project path in message
    speak = false,                 -- also speak a short message via `say` (macOS)
    voice = nil,                   -- voice for `say` (e.g., 'Samantha')
    backend = 'terminal-notifier', -- preferred backend on macOS ('terminal-notifier' | 'osascript')
    terminal_notifier = {
      ignore_dnd = true,           -- pass -ignoreDnD to bypass Do Not Disturb
      sender = 'com.apple.Terminal',
      group = 'codex.nvim',
      activate = 'com.apple.Terminal',
    },
    idle = {                       -- idle detection tuning (used when alert_on_idle=true)
      check_interval = 1500,       -- ms between checks
      idle_checks = 3,             -- consecutive no-change checks
      lines_to_check = 40,         -- tail lines considered for hashing
      require_activity = true,     -- only notify after seeing output first
      min_change_ticks = 3,        -- require at least N content changes before eligible
      min_active_ms = 1500,        -- minimum ms from first content change to idle
      cancel_markers = {           -- suppress idle notify if tail contains any of these
        '🖐  Tell the model what to do differently',
        'Tell the model what to do differently',
        'To get started, describe a task or try one of these commands',
        '/status - show current session configuration',
      },
    },
  },
  terminal = {
    direction = 'horizontal', -- 'horizontal' | 'vertical'
    size = 15,                -- split height/width; if 0< size <1, treated as fraction
    position = nil,           -- override split side: 'left' | 'right' | 'top' | 'bottom' (nil = respect &splitright/&splitbelow)
    provider = 'native',      -- 'native' | 'snacks' | 'auto' (auto uses Snacks if available)
    auto_insert_mode = true,  -- enter insert mode on open
    fix_display_corruption = false, -- redraw after open
    reuse = true,             -- reuse terminal buffer
  },
  terminal_bridge = {
    path_format = 'abs',      -- 'abs' | 'rel' | 'basename' - format for sent paths
    path_prefix = '@',        -- prefix string added to paths (e.g., '@' for Claude Code)
    auto_attach = true,       -- automatically attach terminals created by CodexOpen
    selection_mode = 'reference', -- 'reference' | 'content' - visual selection send format
  },
}

M.options = {}

function M.apply(opts)
  local merged = vim.tbl_deep_extend('force', {}, M.defaults, opts or {})
  local t = merged.terminal or {}

  -- Compatibility aliases
  if t.split_side and not t.position then
    t.position = t.split_side
  end
  if t.split_width_percentage and not t.size then
    t.size = t.split_width_percentage
  end
  if type(t.size) == 'string' then
    local num = tonumber(t.size)
    if num then t.size = num end
  end

  if merged.git_repo_cwd == true or t.git_repo_cwd == true then
    merged.cwd_provider = 'git'
  end

  merged.terminal = t
  M.options = merged
  return M.options
end

return M
