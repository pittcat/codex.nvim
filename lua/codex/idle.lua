local logger = require('codex.logger')
local notifier = require('codex.notify')

local M = {}

local defaults = {
  check_interval = 1500,   -- ms between checks
  idle_checks = 3,         -- consecutive no-change checks to consider idle
  lines_to_check = 40,     -- tail lines considered for hashing
  require_activity = true, -- only notify after some activity was detected
  min_change_ticks = 3,    -- require at least N changes before eligible
  min_active_ms = 1500,    -- require at least this long between first change and idle
  cancel_markers = {       -- if any of these substrings appear in tail, treat as canceled and do not notify
    'Request interrupted by user',
    'interrupted by user',
    'Canceled',
    'Cancelled',
    '🖐  Tell the model what to do differently',
    'Tell the model what to do differently',
    '取消',
    -- Prevent false positives when Codex just opened and shows the welcome/help screen
    'To get started, describe a task or try one of these commands',
    '/status - show current session configuration',
  },
}

local monitors = {} -- bufnr -> { timer, last_hash, no_change, saw_activity, idle_notified, cwd, opts, change_ticks, first_change_ts }

local function simple_hash(str)
  if not str or str == '' then return 'empty' end
  local h = 0
  for i = 1, #str do
    h = (h * 31 + string.byte(str, i)) % 2147483647
  end
  return tostring(h)
end

local function get_tail_content(bufnr, lines_to_check)
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then return '', false end
  local total = vim.api.nvim_buf_line_count(bufnr)
  local start = math.max(0, total - lines_to_check)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start, -1, false)
  -- collapse consecutive trailing blanks lightly
  local collected, nonempty_seen = {}, false
  for i = #lines, 1, -1 do
    local line = lines[i]
    if line and line:match('%S') then
      nonempty_seen = true
      table.insert(collected, 1, line)
      if #collected >= lines_to_check then break end
    elseif nonempty_seen then
      table.insert(collected, 1, line)
    end
  end
  return table.concat(collected, '\n'), true
end

local function stop_timer(bufnr)
  local m = monitors[bufnr]
  if m and m.timer then
    pcall(m.timer.stop, m.timer)
    pcall(m.timer.close, m.timer)
    m.timer = nil
  end
end

function M.stop(bufnr)
  if bufnr and monitors[bufnr] then
    stop_timer(bufnr)
    monitors[bufnr] = nil
  end
end

function M.stop_all()
  for b,_ in pairs(monitors) do M.stop(b) end
end

--- Start idle monitor on a terminal buffer
--- @param bufnr integer terminal buffer id
--- @param cwd string|nil cwd for notification context
--- @param user table|nil { check_interval, idle_checks, lines_to_check, require_activity }
function M.start(bufnr, cwd, user)
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then return false end
  local opts = vim.tbl_deep_extend('force', vim.deepcopy(defaults), user or {})

  -- idempotent: restart existing with new opts
  if monitors[bufnr] then
    stop_timer(bufnr)
  end

  monitors[bufnr] = {
    timer = vim.loop.new_timer(),
    last_hash = '',
    no_change = 0,
    saw_activity = false,
    idle_notified = false,
    change_ticks = 0,
    first_change_ts = nil,
    cwd = cwd,
    opts = opts,
  }

  local function tick()
    local m = monitors[bufnr]
    if not m then return end
    if not vim.api.nvim_buf_is_valid(bufnr) then
      M.stop(bufnr)
      return
    end

    -- Only monitor terminal buffers
    if vim.api.nvim_buf_get_option(bufnr, 'buftype') ~= 'terminal' then
      M.stop(bufnr)
      return
    end

    local content, ok = get_tail_content(bufnr, m.opts.lines_to_check)
    if not ok then return end

    -- Detect explicit cancellation markers in tail content; if present, stop monitoring without notifying
    do
      local markers = m.opts.cancel_markers or {}
      -- case-insensitive substring matching
      local hay = tostring(content):lower()
      for _, mark in ipairs(markers) do
        local needle = (mark ~= nil) and tostring(mark):lower() or ''
        if needle ~= '' and hay:find(needle, 1, true) then
          logger.debug('idle', 'Cancellation marker detected; suppressing idle notification and stopping monitor')
          M.stop(bufnr)
          return
        end
      end
    end
    local h = simple_hash(content)
    -- On first observation, establish a baseline without counting as activity.
    if m.last_hash == '' then
      m.last_hash = h
      m.no_change = 0
      return
    end
    if h ~= m.last_hash then
      m.last_hash = h
      m.no_change = 0
      m.saw_activity = true
      m.idle_notified = false
      m.change_ticks = (m.change_ticks or 0) + 1
      if not m.first_change_ts and vim.loop and vim.loop.hrtime then
        m.first_change_ts = vim.loop.hrtime() -- ns
      end
      return
    end

    -- unchanged
    m.no_change = m.no_change + 1
    if m.no_change >= m.opts.idle_checks then
      -- Optional time-based guard: require a small active period before idle can trigger
      local time_ok = true
      local min_active_ms = tonumber(m.opts.min_active_ms or 0) or 0
      if min_active_ms > 0 and m.first_change_ts and vim.loop and vim.loop.hrtime then
        local elapsed_ms = (vim.loop.hrtime() - m.first_change_ts) / 1e6
        time_ok = (elapsed_ms >= min_active_ms)
      end

      if time_ok
        and ((not m.opts.require_activity) or m.saw_activity)
        and ((m.change_ticks or 0) >= (m.opts.min_change_ticks or 0)) then
        if not m.idle_notified then
          m.idle_notified = true
          -- Send an explicit idle notification instead of a job-exit success
          if notifier.idle then
            notifier.idle(m.cwd)
          else
            notifier.job_exit(true, 0, m.cwd)
          end
          -- Stop monitoring after first idle notification to avoid repeated checks
          M.stop(bufnr)
        end
      end
    end
  end

  monitors[bufnr].timer:start(1000, opts.check_interval, vim.schedule_wrap(tick))

  -- auto stop on buffer wipe/term close
  local group = vim.api.nvim_create_augroup('CodexIdleMon', { clear = false })
  vim.api.nvim_create_autocmd({ 'BufWipeout', 'TermClose' }, {
    group = group,
    buffer = bufnr,
    once = true,
    callback = function()
      M.stop(bufnr)
    end,
  })

  logger.debug('idle', 'Started idle monitor on bufnr', bufnr)
  return true
end

return M
