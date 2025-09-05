local M = {
  state = {
    bufnr = nil,
    winid = nil,
    jobs = {},
  }
}

local logger = require('codex.logger')

local function is_headless()
  local uis = vim.api and vim.api.nvim_list_uis and vim.api.nvim_list_uis() or {}
  return not uis or #uis == 0
end

local function open_split(direction, size)
  if is_headless() then
    -- No UI attached; cannot create splits. Caller should avoid window ops.
    return nil
  end
  if direction == 'vertical' then
    vim.cmd('vsplit')
    if size and size > 0 then vim.cmd(size .. 'vertical resize') end
  else
    vim.cmd('split')
    if size and size > 0 then vim.cmd(size .. 'resize') end
  end
  return vim.api.nvim_get_current_win()
end

local function close_if_invalid()
  if M.state.bufnr and not vim.api.nvim_buf_is_valid(M.state.bufnr) then
    M.state.bufnr = nil
    M.state.winid = nil
  end
  if M.state.winid and not vim.api.nvim_win_is_valid(M.state.winid) then
    M.state.winid = nil
  end
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
  if M.state.bufnr then
    -- Reopen in a split
    local win = open_split('horizontal', 10)
    if win then
      vim.api.nvim_win_set_buf(win, M.state.bufnr)
      M.state.winid = win
    end
    return true
  end
  return false
end

function M.simple_toggle()
  close_if_invalid()
  if M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) then
    vim.api.nvim_win_close(M.state.winid, true)
    M.state.winid = nil
    return
  end
  M.ensure_visible()
end

---Run a command in a terminal split
---@param cmd string[] list
---@param opts table { direction, size, cwd, env, reuse }
function M.run(cmd, opts)
  opts = opts or {}
  local reuse = opts.reuse ~= false

  if is_headless() then
    local job_opts = {}
    if opts.cwd then job_opts.cwd = opts.cwd end
    if opts.env and next(opts.env) then job_opts.env = opts.env end
    local job = vim.fn.jobstart(cmd, job_opts)
    if job <= 0 then
      logger.error('terminal', 'Failed to start headless job: ' .. tostring(job))
    else
      table.insert(M.state.jobs, job)
    end
    return nil, nil
  end

  if reuse and M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
    -- Reuse existing terminal buffer by re-running termopen in that buffer
    if not is_headless() then
      if M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) then
        vim.api.nvim_set_current_win(M.state.winid)
      else
        M.state.winid = open_split(opts.direction or 'horizontal', opts.size or 15)
        if M.state.winid then
          vim.api.nvim_win_set_buf(M.state.winid, M.state.bufnr)
        end
      end
    end
    local term_opts = {}
    if opts.cwd then term_opts.cwd = opts.cwd end
    if opts.env and next(opts.env) then term_opts.env = opts.env end
    vim.api.nvim_buf_call(M.state.bufnr, function()
      vim.fn.termopen(cmd, term_opts)
    end)
    if not is_headless() then
      vim.cmd('startinsert')
    end
    return M.state.bufnr, M.state.winid
  end

  local win = open_split(opts.direction or 'horizontal', opts.size or 15)
  local buf = vim.api.nvim_create_buf(false, true)
  if win then
    vim.api.nvim_win_set_buf(win, buf)
  end

  local term_opts = {}
  if opts.cwd then term_opts.cwd = opts.cwd end
  if opts.env and next(opts.env) then term_opts.env = opts.env end

  local job = vim.fn.termopen(cmd, term_opts)
  if job <= 0 then
    logger.error('terminal', 'Failed to start job: ' .. tostring(job))
  end

  M.state.bufnr = buf
  M.state.winid = win

  -- Enter insert mode for interactive TUI
  if not is_headless() then
    vim.cmd('startinsert')
  end

  return buf, win
end

return M
