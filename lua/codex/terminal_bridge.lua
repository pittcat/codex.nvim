local logger = require('codex.logger')

local M = {
  -- 存储每个 tab 对应的终端信息
  tab_terminals = {}
}

--- 自动附着终端到当前 tab
---@param bufnr number 终端 buffer 编号
---@param winid number|nil 终端窗口 ID
---@return boolean 是否成功附着
function M.auto_attach(bufnr, winid)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    logger.warn('terminal_bridge', 'Invalid buffer for auto attach:', bufnr)
    return false
  end

  local tab_id = vim.api.nvim_get_current_tabpage()
  local job_id = vim.b[bufnr].terminal_job_id
  
  if not job_id then
    logger.warn('terminal_bridge', 'No terminal_job_id found for buffer:', bufnr)
    return false
  end

  M.tab_terminals[tab_id] = {
    bufnr = bufnr,
    winid = winid,
    job_id = job_id
  }

  logger.debug('terminal_bridge', 'Auto attached terminal - tab:', tab_id, 'bufnr:', bufnr, 'job_id:', job_id)
  return true
end

--- 获取当前 tab 的终端信息
---@return table|nil 终端信息 {bufnr, winid, job_id} 或 nil
function M.get_current_tab_terminal()
  local tab_id = vim.api.nvim_get_current_tabpage()
  local term_info = M.tab_terminals[tab_id]
  
  if not term_info then
    return nil
  end

  -- 检查 buffer 是否仍然有效
  if not vim.api.nvim_buf_is_valid(term_info.bufnr) then
    logger.debug('terminal_bridge', 'Terminal buffer invalid, cleaning up tab:', tab_id)
    M.tab_terminals[tab_id] = nil
    return nil
  end

  -- 检查 job_id 是否仍然有效
  if not vim.b[term_info.bufnr].terminal_job_id then
    logger.debug('terminal_bridge', 'Terminal job_id missing, cleaning up tab:', tab_id)
    M.tab_terminals[tab_id] = nil
    return nil
  end

  return term_info
end

--- 格式化文件路径
---@param path string 原始路径
---@param format string 格式类型: 'abs' | 'rel' | 'basename'
---@param prefix string|nil 可选前缀
---@return string 格式化后的路径
function M.format_path(path, format, prefix)
  local formatted_path = path
  
  if format == 'rel' then
    -- 相对于当前工作目录
    formatted_path = vim.fn.fnamemodify(path, ':.')
  elseif format == 'basename' then
    -- 仅文件名
    formatted_path = vim.fn.fnamemodify(path, ':t')
  elseif format == 'abs' then
    -- 绝对路径 (默认)
    formatted_path = vim.fn.fnamemodify(path, ':p')
  end

  -- 添加前缀
  if prefix and prefix ~= '' then
    formatted_path = prefix .. formatted_path
  end

  return formatted_path
end

--- 发送当前 buffer 路径到当前 tab 的终端
---@param opts table|nil 配置选项
---@return boolean 是否发送成功
function M.send_buffer_path(opts)
  opts = opts or {}
  
  -- 获取当前 buffer 路径
  local current_buf = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(current_buf)
  
  if buf_name == '' then
    buf_name = '<unnamed>'
    logger.info('terminal_bridge', 'Sending unnamed buffer')
  end

  -- 获取当前 tab 的终端信息
  local term_info = M.get_current_tab_terminal()
  if not term_info then
    vim.notify('No terminal found in current tab. Please run :CodexOpen first.', vim.log.levels.WARN)
    return false
  end

  -- 格式化路径
  local formatted_path = M.format_path(
    buf_name, 
    opts.path_format or 'abs',
    opts.path_prefix
  )

  -- 发送到终端
  local success = pcall(vim.fn.chansend, term_info.job_id, formatted_path .. '\n')
  
  if success then
    logger.info('terminal_bridge', 'Sent path to terminal:', formatted_path)
    return true
  else
    logger.error('terminal_bridge', 'Failed to send path to terminal, job_id:', term_info.job_id)
    vim.notify('Failed to send path to terminal. Terminal may have been closed.', vim.log.levels.ERROR)
    -- 清理无效的终端信息
    local tab_id = vim.api.nvim_get_current_tabpage()
    M.tab_terminals[tab_id] = nil
    return false
  end
end

--- 清理指定 tab 的终端信息（当终端被关闭时调用）
---@param tab_id number|nil tab ID，nil 表示当前 tab
function M.cleanup_tab_terminal(tab_id)
  tab_id = tab_id or vim.api.nvim_get_current_tabpage()
  if M.tab_terminals[tab_id] then
    logger.debug('terminal_bridge', 'Cleaning up terminal for tab:', tab_id)
    M.tab_terminals[tab_id] = nil
  end
end

--- 清理所有无效的终端信息
function M.cleanup_invalid_terminals()
  local cleaned = 0
  for tab_id, term_info in pairs(M.tab_terminals) do
    if not vim.api.nvim_buf_is_valid(term_info.bufnr) or 
       not vim.b[term_info.bufnr].terminal_job_id then
      M.tab_terminals[tab_id] = nil
      cleaned = cleaned + 1
    end
  end
  if cleaned > 0 then
    logger.debug('terminal_bridge', 'Cleaned up', cleaned, 'invalid terminals')
  end
end

--- 获取 visual 选择的范围
---@param args table|nil 命令参数，包含 line1 和 line2
---@return number start_line 开始行号
---@return number end_line 结束行号
function M.get_visual_selection_range(args)
  -- 如果有命令参数，使用命令范围
  if args and args.line1 and args.line2 then
    return args.line1, args.line2
  end

  -- 获取 visual 选择标记
  local start_line = vim.fn.getpos("'<")[2]
  local end_line = vim.fn.getpos("'>")[2]

  -- 如果标记未设置（没有 visual 选择），使用当前行
  if start_line == 0 or end_line == 0 then
    local line = vim.fn.line('.')
    return line, line
  end

  return start_line, end_line
end

--- 获取相对文件路径
---@return string filepath 相对于当前工作目录的路径
function M.get_relative_filepath()
  return vim.fn.fnamemodify(vim.fn.expand('%'), ':~:.')
end

--- 格式化文件引用
---@param filepath string 文件路径
---@param start_line number 开始行号
---@param end_line number 结束行号
---@return string reference 格式化的引用（如 @file.lua#L10-L20）
function M.format_reference(filepath, start_line, end_line)
  if start_line == end_line then
    return string.format('@%s#L%d', filepath, start_line)
  else
    return string.format('@%s#L%d-L%d', filepath, start_line, end_line)
  end
end

--- 发送 visual 选择的文件引用到终端
---@param args table|nil 命令参数
---@return boolean 是否发送成功
function M.send_visual_reference(args)
  -- 获取文件路径
  local filepath = M.get_relative_filepath()
  if filepath == '' then
    vim.notify('No file in current buffer', vim.log.levels.WARN)
    return false
  end

  -- 获取选择范围
  local start_line, end_line = M.get_visual_selection_range(args)
  
  -- 格式化引用
  local reference = M.format_reference(filepath, start_line, end_line)

  -- 获取当前 tab 的终端信息
  local term_info = M.get_current_tab_terminal()
  if not term_info then
    vim.notify('No terminal found in current tab. Please run :CodexOpen first.', vim.log.levels.WARN)
    return false
  end

  -- 发送到终端
  local success = pcall(vim.fn.chansend, term_info.job_id, reference .. '\n')
  
  if success then
    logger.info('terminal_bridge', 'Sent reference to terminal:', reference)
    return true
  else
    logger.error('terminal_bridge', 'Failed to send reference to terminal, job_id:', term_info.job_id)
    vim.notify('Failed to send reference to terminal. Terminal may have been closed.', vim.log.levels.ERROR)
    -- 清理无效的终端信息
    local tab_id = vim.api.nvim_get_current_tabpage()
    M.tab_terminals[tab_id] = nil
    return false
  end
end

--- 发送 visual 选择的内容到终端
---@param args table|nil 命令参数
---@return boolean 是否发送成功  
function M.send_visual_content(args)
  -- 获取文件路径
  local filepath = M.get_relative_filepath()
  if filepath == '' then
    vim.notify('No file in current buffer', vim.log.levels.WARN)
    return false
  end

  -- 获取选择范围
  local start_line, end_line = M.get_visual_selection_range(args)
  
  -- 格式化引用
  local reference = M.format_reference(filepath, start_line, end_line)
  
  -- 获取实际的代码内容
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local content = table.concat(lines, '\n')
  local text_to_send = reference .. '\n' .. content

  -- 获取当前 tab 的终端信息
  local term_info = M.get_current_tab_terminal()
  if not term_info then
    vim.notify('No terminal found in current tab. Please run :CodexOpen first.', vim.log.levels.WARN)
    return false
  end

  -- 发送到终端
  local success = pcall(vim.fn.chansend, term_info.job_id, text_to_send .. '\n')
  
  if success then
    logger.info('terminal_bridge', 'Sent content to terminal:', reference)
    return true
  else
    logger.error('terminal_bridge', 'Failed to send content to terminal, job_id:', term_info.job_id)
    vim.notify('Failed to send content to terminal. Terminal may have been closed.', vim.log.levels.ERROR)
    -- 清理无效的终端信息
    local tab_id = vim.api.nvim_get_current_tabpage()
    M.tab_terminals[tab_id] = nil
    return false
  end
end

--- 获取所有活跃的终端信息（调试用）
---@return table 所有 tab 的终端信息
function M.get_all_terminals()
  M.cleanup_invalid_terminals()
  return M.tab_terminals
end

return M