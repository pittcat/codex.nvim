local M = {
  state = {
    bufnr = nil,
    winid = nil,
    jobs = {},
    snacks_term = nil,
  }
}

local logger = require('codex.logger')
local notifier = require('codex.notify')
local idlemon = require('codex.idle')
local terminal_bridge = require('codex.terminal_bridge')

local function send_exit_alert(code, cwd)
  local ok = (code == 0)
  notifier.job_exit(ok, tonumber(code) or -1, cwd)
end

local function is_headless()
  local uis = vim.api and vim.api.nvim_list_uis and vim.api.nvim_list_uis() or {}
  return not uis or #uis == 0
end

local function sanitize_env(env)
  if type(env) ~= 'table' then return nil end
  local out, has = {}, false
  for k, v in pairs(env) do
    if v ~= nil then
      out[tostring(k)] = tostring(v)
      has = true
    end
  end
  if has then return out end
  return nil
end

local function normalize_size(direction, size)
  if not size or size <= 0 then return nil end
  -- Support fractional size (0 < size < 1) as a portion of the CURRENT window
  if size > 0 and size < 1 then
    if not is_headless() then
      local win = vim.api.nvim_get_current_win()
      if direction == 'vertical' then
        local width = vim.api.nvim_win_get_width(win)
        return math.max(1, math.floor(width * size))
      else
        local height = vim.api.nvim_win_get_height(win)
        return math.max(1, math.floor(height * size))
      end
    else
      -- Headless: fallback to editor dimensions
      if direction == 'vertical' then
        return math.floor(vim.o.columns * size)
      else
        local total = vim.o.lines - vim.o.cmdheight
        return math.floor(total * size)
      end
    end
  end
  return size
end

local function open_split(direction, size, position)
  if is_headless() then
    -- No UI attached; cannot create splits. Caller should avoid window ops.
    return nil
  end
  local final_size = normalize_size(direction, size)
  local prefix = ''
  -- Respect explicit side if provided; otherwise leave to user's splitright/splitbelow
  if position == 'left' then prefix = 'leftabove '
  elseif position == 'right' then prefix = 'rightbelow '
  elseif position == 'top' then prefix = 'aboveleft '
  elseif position == 'bottom' then prefix = 'belowright '
  end

  if direction == 'vertical' then
    vim.cmd(prefix .. 'vsplit')
    local win = vim.api.nvim_get_current_win()
    if final_size and final_size > 0 then
      local ok = pcall(vim.api.nvim_win_set_width, win, final_size)
      if not ok then
        vim.cmd(('vertical resize %d'):format(final_size))
      end
    end
    return win
  else
    vim.cmd(prefix .. 'split')
    local win = vim.api.nvim_get_current_win()
    if final_size and final_size > 0 then
      local ok = pcall(vim.api.nvim_win_set_height, win, final_size)
      if not ok then
        vim.cmd(('resize %d'):format(final_size))
      end
    end
    return win
  end
end

local function close_if_invalid()
  logger.debug('cleanup', 'Before cleanup - bufnr:', M.state.bufnr, 'winid:', M.state.winid)
  if M.state.bufnr and not vim.api.nvim_buf_is_valid(M.state.bufnr) then
    logger.debug('cleanup', 'Invalid buffer detected, clearing bufnr and winid')
    M.state.bufnr = nil
    M.state.winid = nil
  end
  if M.state.winid and not vim.api.nvim_win_is_valid(M.state.winid) then
    logger.debug('cleanup', 'Invalid window detected, clearing winid')
    M.state.winid = nil
  end
  logger.debug('cleanup', 'After cleanup - bufnr:', M.state.bufnr, 'winid:', M.state.winid)
end

function M.get_active_terminal_bufnr()
  close_if_invalid()
  return M.state.bufnr
end

function M.ensure_visible()
  close_if_invalid()
  if M.state.bufnr and M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) then
    return true
  end
  -- If we have a Snacks terminal object, try to show it again
  if M.state.snacks_term and M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
    local ok = pcall(function()
      if M.state.snacks_term.show then M.state.snacks_term:show() end
    end)
    if ok then
      M.state.winid = vim.fn.bufwinid(M.state.bufnr)
      if M.state.winid ~= -1 then
        return true
      end
    end
  end
  if M.state.bufnr then
    -- Reopen in a split
    local win = open_split('horizontal', 10, nil)
    if win then
      vim.api.nvim_win_set_buf(win, M.state.bufnr)
      M.state.winid = win
    end
    return true
  end
  return false
end

function M.simple_toggle()
  logger.debug('toggle', 'Starting simple_toggle - state check')
  logger.debug('toggle', 'snacks_term:', M.state.snacks_term and 'exists' or 'nil')
  logger.debug('toggle', 'bufnr:', M.state.bufnr, 'valid:', M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) or 'n/a')
  logger.debug('toggle', 'winid:', M.state.winid, 'valid:', M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) or 'n/a')
  
  close_if_invalid()
  logger.debug('toggle', 'After close_if_invalid - bufnr:', M.state.bufnr, 'winid:', M.state.winid)
  
  -- Handle snacks terminal toggle
  if M.state.snacks_term then
    logger.debug('toggle', 'Using snacks terminal toggle')
    local ok = pcall(function()
      M.state.snacks_term:toggle()
    end)
    logger.debug('toggle', 'Snacks toggle result:', ok)
    if ok then
      -- update win id if now visible
      local wid = vim.fn.bufwinid(M.state.bufnr or -1)
      logger.debug('toggle', 'After snacks toggle - bufwinid:', wid)
      if wid ~= -1 then M.state.winid = wid else M.state.winid = nil end
      logger.debug('toggle', 'Updated winid to:', M.state.winid)
      return
    end
  end
  
  -- Handle native terminal toggle
  logger.debug('toggle', 'Using native terminal toggle')
  if M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) then
    logger.debug('toggle', 'Closing existing window:', M.state.winid)
    vim.api.nvim_win_close(M.state.winid, true)
    M.state.winid = nil
    logger.debug('toggle', 'Window closed, winid set to nil')
  else
    logger.debug('toggle', 'No valid window, calling ensure_visible')
    -- Show existing terminal buffer
    M.ensure_visible()
  end
end

---Run a command in a terminal split
---@param cmd string[] list
---@param opts table { direction, size, position, cwd, env, reuse, auto_insert, fix_display_corruption, provider }
function M.run(cmd, opts)
  opts = opts or {}
  local reuse = opts.reuse ~= false
  local previous_win = nil
  if not is_headless() then
    previous_win = vim.api.nvim_get_current_win()
  end
  if not is_headless() and (opts.provider == 'snacks' or opts.provider == 'auto') then
    local ok, Snacks = pcall(require, 'snacks')
    if ok and Snacks and Snacks.terminal then
      -- Determine side and dimension
      local side = opts.position
      if not side then
        if (opts.direction or 'horizontal') == 'vertical' then
          side = (vim.o.splitright and 'right' or 'left')
        else
          side = (vim.o.splitbelow and 'bottom' or 'top')
        end
      end

      local win = { style = 'terminal', position = side }
      -- Control whether we enter the terminal window based on auto_insert
      win.enter = (opts.auto_insert ~= false)
      local size = normalize_size(opts.direction or 'horizontal', opts.size)
      if (opts.direction or 'horizontal') == 'vertical' then
        -- width (absolute columns)
        if size and size > 0 then win.width = size end
      else
        -- height (absolute rows)
        if size and size > 0 then win.height = size end
      end

      local term_opts = {
        win = win,
        cwd = opts.cwd,
        env = sanitize_env(opts.env),
        interactive = true,
        start_insert = opts.auto_insert ~= false,
        auto_insert = opts.auto_insert ~= false,
        auto_close = false,
      }
      local term = Snacks.terminal.open(cmd, term_opts)
      logger.debug('run', 'Snacks terminal created:', term and 'success' or 'failed')
      -- Track state for toggle and reuse semantics
      if term then
        M.state.snacks_term = term
        M.state.bufnr = term.buf
        M.state.winid = term.win
        logger.debug('run', 'State set - snacks_term: exists, bufnr:', term.buf, 'winid:', term.win)
        -- Auto-attach terminal bridge if enabled
        if opts.terminal_bridge_auto_attach then
          terminal_bridge.auto_attach(term.buf, term.win)
        end
        -- Start idle monitor for ongoing tasks if enabled
        if opts.alert_on_idle and M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
          local idle_opts = (opts.notification and opts.notification.idle) or {}
          idlemon.start(M.state.bufnr, opts.cwd, idle_opts)
        end
        -- Alerts: hook TermClose on the terminal buffer if requested
        if opts.alert_on_exit and term and term.on then
          pcall(function()
            term:on('TermClose', function()
              local code = (vim.v and vim.v.event and vim.v.event.status) or nil
              send_exit_alert(tonumber(code) or -1, opts.cwd)
            end, { buf = true })
          end)
        elseif opts.alert_on_exit and M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
          -- Fallback: buffer-local TermClose autocmd
          local group = vim.api.nvim_create_augroup('CodexTermAlerts', { clear = false })
          vim.api.nvim_create_autocmd('TermClose', {
            group = group,
            buffer = M.state.bufnr,
            once = true,
            callback = function()
              local code = (vim.v and vim.v.event and vim.v.event.status) or nil
              send_exit_alert(tonumber(code) or -1, opts.cwd)
            end,
          })
        end
      else
        -- Fallback to current window/buffer if any
        local wid = vim.api.nvim_get_current_win()
        local bid = vim.api.nvim_win_is_valid(wid) and vim.api.nvim_win_get_buf(wid) or nil
        M.state.winid = wid
        M.state.bufnr = bid
        logger.debug('run', 'Fallback state - winid:', wid, 'bufnr:', bid)
      end

      if opts.fix_display_corruption then
        vim.schedule(function() pcall(vim.cmd, 'redraw!') end)
      end
      -- If not auto-insert, keep focus on previous window
      if previous_win and (opts.auto_insert == false) and vim.api.nvim_win_is_valid(previous_win) then
        pcall(vim.api.nvim_set_current_win, previous_win)
      end
      return M.state.bufnr, M.state.winid
    else
      if opts.provider == 'snacks' then
        logger.warn('terminal', 'Provider snacks not available; falling back to native')
      end
      -- if provider == 'auto' and snacks missing, just fall back silently
    end
  end
  if opts.provider and (opts.provider ~= 'native' and opts.provider ~= 'auto') then
    logger.warn('terminal', 'Provider ' .. tostring(opts.provider) .. ' not integrated; using native')
  end

  if is_headless() then
    local job_opts = {}
    if opts.cwd then job_opts.cwd = opts.cwd end
    local env = sanitize_env(opts.env)
    if env then job_opts.env = env end
    if opts.alert_on_exit then
      job_opts.on_exit = function(_, code, _)
        send_exit_alert(tonumber(code) or -1, opts.cwd)
      end
    end
    local job = vim.fn.jobstart(cmd, job_opts)
    if job <= 0 then
      logger.error('terminal', 'Failed to start headless job: ' .. tostring(job))
    else
      table.insert(M.state.jobs, job)
    end
    -- Note: terminal_bridge is not supported in headless mode
    -- as there are no terminal buffers with terminal_job_id
    return nil, nil
  end

  if reuse and M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
    -- Reuse existing terminal buffer by re-running termopen in that buffer
    if not is_headless() then
      if M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) then
        if opts.auto_insert ~= false then
          vim.api.nvim_set_current_win(M.state.winid)
        end
      else
        M.state.winid = open_split(opts.direction or 'horizontal', opts.size or 15, opts.position)
        if M.state.winid then
          vim.api.nvim_win_set_buf(M.state.winid, M.state.bufnr)
        end
      end
    end
    local term_opts = {}
    if opts.cwd then term_opts.cwd = opts.cwd end
    local env = sanitize_env(opts.env)
    if env then term_opts.env = env end
    if opts.alert_on_exit then
      term_opts.on_exit = function(_, code, _)
        send_exit_alert(tonumber(code) or -1, opts.cwd)
      end
    end
    vim.api.nvim_buf_call(M.state.bufnr, function()
      vim.fn.termopen(cmd, term_opts)
    end)
    -- Auto-attach terminal bridge on reuse if enabled
    if opts.terminal_bridge_auto_attach then
      terminal_bridge.auto_attach(M.state.bufnr, M.state.winid)
    end
    -- ensure idle monitor is running on reuse as well
    if opts.alert_on_idle and M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
      local idle_opts = (opts.notification and opts.notification.idle) or {}
      idlemon.start(M.state.bufnr, opts.cwd, idle_opts)
    end
    if not is_headless() then
      if opts.auto_insert ~= false then
        vim.cmd('startinsert')
      else
        -- restore previous focus
        if previous_win and vim.api.nvim_win_is_valid(previous_win) then
          pcall(vim.api.nvim_set_current_win, previous_win)
        end
      end
    end
    return M.state.bufnr, M.state.winid
  end

  local win = open_split(opts.direction or 'horizontal', opts.size or 15, opts.position)
  local buf = vim.api.nvim_create_buf(false, true)
  if win then
    vim.api.nvim_win_set_buf(win, buf)
  end

  local term_opts = {}
  if opts.cwd then term_opts.cwd = opts.cwd end
  local env = sanitize_env(opts.env)
  if env then term_opts.env = env end
  if opts.alert_on_exit then
    term_opts.on_exit = function(_, code, _)
      send_exit_alert(tonumber(code) or -1, opts.cwd)
    end
  end

  local job = vim.fn.termopen(cmd, term_opts)
  if job <= 0 then
    logger.error('terminal', 'Failed to start job: ' .. tostring(job))
  end

  M.state.bufnr = buf
  M.state.winid = win
  logger.debug('run', 'Native terminal state - bufnr:', buf, 'winid:', win)

  -- Auto-attach terminal bridge if enabled
  if opts.terminal_bridge_auto_attach then
    terminal_bridge.auto_attach(buf, win)
  end

  -- start idle monitor for new terminals
  if opts.alert_on_idle and M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
    local idle_opts = (opts.notification and opts.notification.idle) or {}
    idlemon.start(M.state.bufnr, opts.cwd, idle_opts)
  end

  -- Enter insert mode for interactive TUI
  if not is_headless() then
    if opts.auto_insert ~= false then
      vim.cmd('startinsert')
    else
      -- focus back previous window
      if previous_win and vim.api.nvim_win_is_valid(previous_win) then
        pcall(vim.api.nvim_set_current_win, previous_win)
      end
    end
  end

  if opts.fix_display_corruption then
    vim.schedule(function()
      pcall(vim.cmd, 'redraw!')
    end)
  end

  return buf, win
end

return M
