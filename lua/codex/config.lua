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
  terminal = {
    direction = 'horizontal', -- 'horizontal' | 'vertical'
    size = 15,                -- split height/width; if 0< size <1, treated as fraction
    position = nil,           -- override split side: 'left' | 'right' | 'top' | 'bottom' (nil = respect &splitright/&splitbelow)
    provider = 'native',      -- 'native' | 'snacks' | 'auto' (auto uses Snacks if available)
    auto_insert_mode = true,  -- enter insert mode on open
    fix_display_corruption = false, -- redraw after open
    reuse = true,             -- reuse terminal buffer
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
