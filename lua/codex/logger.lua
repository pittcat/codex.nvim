local M = {}

-- Try to use base.nvim's logger if available; fall back to vim.notify
local ok, vlog = pcall(require, 'base.log')

if ok and type(vlog.new) == 'function' then
  local log = vlog.new {
    plugin = 'codex.nvim',
    use_console = true,
    highlights = true,
    use_file = false,
    level = vim.env.CODEX_LOG_LEVEL or "info",
    modes = {
      { name = "trace", hl = "Comment" },
      { name = "debug", hl = "Comment" },
      { name = "info", hl = "Directory" },
      { name = "warn", hl = "WarningMsg" },
      { name = "error", hl = "ErrorMsg" },
      { name = "fatal", hl = "ErrorMsg" },
    },
    float_precision = 0.01,
  }
  M = log
else
  -- Minimal shim
  local function notify(level, ...)
    local msg = table.concat(vim.tbl_map(tostring, {...}), ' ')
    vim.notify(msg, level, { title = 'codex.nvim' })
  end
  M.trace = function(...) notify(vim.log.levels.TRACE or vim.log.levels.DEBUG, ...) end
  M.debug = function(...) notify(vim.log.levels.DEBUG, ...) end
  M.info  = function(...) notify(vim.log.levels.INFO,  ...) end
  M.warn  = function(...) notify(vim.log.levels.WARN,  ...) end
  M.error = function(...) notify(vim.log.levels.ERROR, ...) end
end

return M

