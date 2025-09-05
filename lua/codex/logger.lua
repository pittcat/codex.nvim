-- claudecode-style leveled logger with component prefixes and fast-event safety
local M = {}

M.levels = {
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  DEBUG = 4,
  TRACE = 5,
}

local level_values = {
  error = M.levels.ERROR,
  warn = M.levels.WARN,
  info = M.levels.INFO,
  debug = M.levels.DEBUG,
  trace = M.levels.TRACE,
}

local current_log_level_value = M.levels.INFO
local file_logging_enabled = false
local file_handle = nil
local file_path = nil

---Setup the logger with options
---@param opts table|nil opts.log_level can be one of: "trace","debug","info","warn","error"
local function path_join(a, b)
  local sep = package.config:sub(1, 1)
  if a:sub(-1) == sep then return a .. b end
  return a .. sep .. b
end

local function init_file_logging(opts)
  -- Determine path if enabled
  file_logging_enabled = false
  if file_handle then
    pcall(function() file_handle:flush(); file_handle:close() end)
    file_handle = nil
  end
  file_path = nil

  local to_file = opts and opts.log_to_file
  if not to_file then return end

  local custom_path = opts.log_file or (type(to_file) == 'string' and to_file or nil)
  if not custom_path or custom_path == '' then
    local ok, tmp = pcall(function()
      return (vim.loop and vim.loop.os_tmpdir and vim.loop.os_tmpdir()) or vim.env.TMPDIR or vim.env.TEMP or vim.env.TMP or '/tmp'
    end)
    local base = (ok and tmp) and tmp or '/tmp'
    file_path = path_join(base, 'codex.nvim.log')
  else
    file_path = custom_path
  end

  -- Open fresh (truncate) each setup
  local ok, fh = pcall(io.open, file_path, 'w')
  if ok and fh then
    file_handle = fh
    file_logging_enabled = true
    -- write header
    local ts = os.date('%Y-%m-%d %H:%M:%S')
    pcall(function()
      fh:write(string.format('== codex.nvim log start [%s] ==\n', ts))
      fh:flush()
    end)
  else
    file_handle = nil
    file_logging_enabled = false
  end
end

function M.setup(opts)
  local desired = (opts and opts.log_level) or vim.env.CODEX_LOG_LEVEL or "info"
  local lower = type(desired) == 'string' and desired:lower() or 'info'
  if level_values[lower] then
    current_log_level_value = level_values[lower]
  else
    current_log_level_value = M.levels.INFO
    vim.schedule(function()
      vim.notify(
        string.format("codex.nvim: invalid log_level '%s', defaulting to info", tostring(desired)),
        vim.log.levels.WARN,
        { title = 'codex.nvim' }
      )
    end)
  end

  -- Initialize file logging based on opts
  init_file_logging(opts)
end

local function build_prefix(level, component)
  local prefix = "[codex.nvim]"
  if component then
    prefix = prefix .. " [" .. component .. "]"
  end
  local name = (level == M.levels.ERROR and 'ERROR')
    or (level == M.levels.WARN and 'WARN')
    or (level == M.levels.INFO and 'INFO')
    or (level == M.levels.DEBUG and 'DEBUG')
    or (level == M.levels.TRACE and 'TRACE')
    or 'LOG'
  return prefix .. " [" .. name .. "]"
end

local function join_message(parts)
  local msg = {}
  for _, p in ipairs(parts) do
    if type(p) == 'table' or type(p) == 'boolean' then
      table.insert(msg, vim.inspect(p))
    else
      table.insert(msg, tostring(p))
    end
  end
  return table.concat(msg, ' ')
end

local function emit(level, component, parts)
  if level > current_log_level_value then return end
  local prefix = build_prefix(level, component)
  local message = join_message(parts)
  -- Always schedule to avoid fast-event issues
  vim.schedule(function()
    -- file logging
    if file_logging_enabled and file_handle then
      local ts = os.date('%Y-%m-%d %H:%M:%S')
      local line = string.format('[%s] %s %s\n', ts, prefix, message)
      pcall(function()
        file_handle:write(line)
        file_handle:flush()
      end)
    end
    if level == M.levels.ERROR then
      vim.notify(prefix .. ' ' .. message, vim.log.levels.ERROR, { title = 'codex.nvim' })
    elseif level == M.levels.WARN then
      vim.notify(prefix .. ' ' .. message, vim.log.levels.WARN, { title = 'codex.nvim' })
    else
      -- INFO/DEBUG/TRACE -> echo to :messages to avoid notification spam
      pcall(vim.api.nvim_echo, { { prefix .. ' ' .. message, 'Normal' } }, true, {})
    end
  end)
end

---Return true if a log level name is enabled
---@param level_name string
function M.is_level_enabled(level_name)
  local v = level_values[(level_name or ''):lower()]
  return v ~= nil and v <= current_log_level_value
end

---Error level
function M.error(component, ...)
  if type(component) ~= 'string' then
    emit(M.levels.ERROR, nil, { component, ... })
  else
    emit(M.levels.ERROR, component, { ... })
  end
end

---Warn level
function M.warn(component, ...)
  if type(component) ~= 'string' then
    emit(M.levels.WARN, nil, { component, ... })
  else
    emit(M.levels.WARN, component, { ... })
  end
end

---Info level
function M.info(component, ...)
  if type(component) ~= 'string' then
    emit(M.levels.INFO, nil, { component, ... })
  else
    emit(M.levels.INFO, component, { ... })
  end
end

---Debug level
function M.debug(component, ...)
  if type(component) ~= 'string' then
    emit(M.levels.DEBUG, nil, { component, ... })
  else
    emit(M.levels.DEBUG, component, { ... })
  end
end

---Trace level
function M.trace(component, ...)
  if type(component) ~= 'string' then
    emit(M.levels.TRACE, nil, { component, ... })
  else
    emit(M.levels.TRACE, component, { ... })
  end
end

return M
