local logger = require('codex.logger')

local M = {}

local defaults = {
  enabled = true,               -- master enable for system notifications
  sound = 'Glass',              -- macOS notification sound name
  title_prefix = 'codex.nvim',  -- title used for system notifications
  include_project_path = false, -- include cwd in message
  speak = false,                -- also speak a short message via `say` (macOS)
  voice = nil,                  -- voice name for `say` (e.g., 'Samantha')
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

local function can_osascript()
  return (vim.fn.executable('osascript') == 1)
end

local function can_say()
  return (vim.fn.executable('say') == 1)
end

local function escape_applescript(s)
  if not s then return '' end
  return tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"')
end

local function macos_notify(title, message, sound)
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
  local title = opts.title_prefix or 'codex.nvim'
  local message
  if ok then
    message = 'Task completed'
  else
    message = ('Task failed (exit code %d)'):format(tonumber(code) or -1)
  end
  if opts.include_project_path and cwd and cwd ~= '' then
    message = message .. '\nPath: ' .. tostring(cwd)
  end

  -- Prefer macOS native with sound; fall back to vim.notify
  local sent = macos_notify(title, message, opts.sound)
  if not sent then
    local level = ok and vim.log.levels.INFO or vim.log.levels.WARN
    vim.schedule(function()
      pcall(vim.notify, ('%s: %s'):format(title, message), level, { title = title })
    end)
  end

  -- Optional speech (disabled unless speak=true)
  local spoken_text = ok and 'Codex task finished' or 'Codex task failed'
  macos_say(spoken_text)

  -- record last sent
  last_sent[key] = { ok = ok, ts = now }
end

return M
