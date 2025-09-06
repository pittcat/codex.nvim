local logger = require('codex.logger')

local M = {}

local defaults = {
  enabled = true,               -- master enable for system notifications
  sound = 'Glass',              -- macOS notification sound name
  title_prefix = 'codex.nvim',  -- title used for system notifications
  include_project_path = false, -- include cwd in message
  speak = false,                -- also speak a short message via `say` (macOS)
  voice = nil,                  -- voice name for `say` (e.g., 'Samantha')
  backend = 'terminal-notifier',-- preferred backend on macOS
  terminal_notifier = {
    ignore_dnd = true,
    sender = 'com.apple.Terminal',
    group = 'codex.nvim',
    activate = 'com.apple.Terminal',
  },
}

local opts = vim.deepcopy(defaults)
local last_sent = {}

function M.setup(user)
  opts = vim.tbl_deep_extend('force', vim.deepcopy(defaults), user or {})
  logger.debug('notify', 'setup opts =', opts)
end

local function is_macos()
  return (vim.fn.has('mac') == 1)
end

local function has_exec(bin)
  return (vim.fn.executable(bin) == 1)
end

local function can_osascript()
  return has_exec('osascript')
end

local function can_say()
  return has_exec('say')
end

local function escape_applescript(s)
  if not s then return '' end
  return tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"')
end

-- terminal-notifier backend
local function tn_notify(title, message, sound)
  if not (is_macos() and has_exec('terminal-notifier')) then return false end
  local tn = opts.terminal_notifier or {}
  local args = {
    'terminal-notifier',
    '-message', tostring(message or ''),
    '-title', tostring(title or (opts.title_prefix or 'codex.nvim')),
    '-sound', tostring(sound or opts.sound or 'Glass'),
    '-sender', tostring(tn.sender or 'com.apple.Terminal'),
    '-group', tostring(tn.group or 'codex.nvim'),
    '-activate', tostring(tn.activate or 'com.apple.Terminal'),
  }
  if tn.ignore_dnd ~= false then
    table.insert(args, '-ignoreDnD')
  end
  vim.fn.jobstart(args, {
    on_exit = function(_, code)
      if code ~= 0 then
        logger.warn('notify', 'terminal-notifier exited with code', code)
      end
    end,
    stdout_buffered = true,
    stderr_buffered = true,
  })
  return true
end

-- osascript fallback backend
local function osascript_notify(title, message, sound)
  if not (is_macos() and can_osascript()) then return false end
  local t = escape_applescript(title)
  local m = escape_applescript(message)
  local snd = escape_applescript(sound or opts.sound)
  local script = string.format('display notification "%s" with title "%s" sound name "%s"', m, t, snd)
  local cmd = { 'osascript', '-e', script }
  vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if code ~= 0 then
        logger.warn('notify', 'osascript exited with code', code)
      end
    end,
  })
  return true
end

local function macos_say(text)
  if not (opts.speak and is_macos() and can_say()) then return false end
  local args
  if opts.voice and opts.voice ~= '' then
    args = { 'say', '-v', tostring(opts.voice), tostring(text) }
  else
    args = { 'say', tostring(text) }
  end
  vim.fn.jobstart(args, { detach = true })
  return true
end

local function send_notification(title, message, ok)
  -- preferred backend
  local backend = (opts.backend or 'terminal-notifier'):lower()
  local sent = false
  if backend == 'terminal-notifier' then
    sent = tn_notify(title, message, opts.sound)
    if not sent then
      sent = osascript_notify(title, message, opts.sound)
    end
  elseif backend == 'osascript' then
    sent = osascript_notify(title, message, opts.sound)
    if not sent then
      sent = tn_notify(title, message, opts.sound)
    end
  end

  if not sent then
    local level = ok and vim.log.levels.INFO or vim.log.levels.WARN
    vim.schedule(function()
      pcall(vim.notify, ('%s: %s'):format(title, message), level, { title = title })
    end)
  end
end

--- Send a job exit system notification and optional voice alert
--- @param ok boolean whether job succeeded
--- @param code integer exit code
--- @param cwd string|nil working directory to include
function M.job_exit(ok, code, cwd)
  if not opts.enabled then return end
  -- de-duplicate: avoid sending multiple success notifications for the same cwd in a short window
  local key = cwd or '__global__'
  local now = (vim.loop and vim.loop.hrtime and (vim.loop.hrtime() / 1000000)) or (os.time() * 1000)
  local prev = last_sent[key]
  if prev then
    -- suppress if both are success and within 30s
    if ok and prev.ok and (now - prev.ts < 30000) then
      return
    end
  end
  local title
  if opts.include_project_path and cwd and cwd ~= '' then
    -- Use project name as title when including path
    title = (cwd:match('([^/\\]+)[/\\]?$') or opts.title_prefix or 'codex.nvim')
  else
    title = opts.title_prefix or 'codex.nvim'
  end
  local message
  if ok then
    message = 'Codex task completed'
  else
    message = ('Codex task failed (exit code %d)'):format(tonumber(code) or -1)
  end
  if opts.include_project_path and cwd and cwd ~= '' then
    message = message .. '\nPath: ' .. tostring(cwd)
  end

  send_notification(title, message, ok)

  -- Optional speech (disabled unless speak=true)
  local spoken_text = ok and 'Codex task finished' or 'Codex task failed'
  macos_say(spoken_text)

  -- record last sent
  last_sent[key] = { ok = ok, ts = now }
end

--- Send an explicit "idle" system notification (non-exit completion)
--- @param cwd string|nil working directory to include
function M.idle(cwd)
  if not opts.enabled then return end
  local key = 'idle:' .. (cwd or '__global__')
  local now = (vim.loop and vim.loop.hrtime and (vim.loop.hrtime() / 1000000)) or (os.time() * 1000)
  local prev = last_sent[key]
  if prev and (now - prev.ts < 30000) then
    return
  end
  local title
  if opts.include_project_path and cwd and cwd ~= '' then
    title = (cwd:match('([^/\\]+)[/\\]?$') or opts.title_prefix or 'codex.nvim')
  else
    title = opts.title_prefix or 'codex.nvim'
  end
  local message = 'Codex terminal is idle'
  if opts.include_project_path and cwd and cwd ~= '' then
    message = message .. '\nPath: ' .. tostring(cwd)
  end
  send_notification(title, message, true)

  local spoken_text = 'Codex is idle'
  macos_say(spoken_text)
  last_sent[key] = { ok = true, ts = now }
end

return M
