local M = {}

local logger = require('codex.logger')

local function is_git_repo(dir)
  local cmd = { 'git', '-C', dir, 'rev-parse', '--is-inside-work-tree' }
  local ok = vim.fn.system(cmd)
  return type(ok) == 'string' and ok:match('true') ~= nil
end

local function git_root(dir)
  local out = vim.fn.systemlist({ 'git', '-C', dir, 'rev-parse', '--show-toplevel' })
  if vim.v.shell_error == 0 and out and out[1] and out[1] ~= '' then
    return out[1]
  end
  return nil
end

function M.get_cwd(provider)
  provider = provider or 'git'
  local file_dir = vim.fn.expand('%:p:h')
  local cwd = vim.loop.cwd()

  if provider == 'file' then
    return (file_dir ~= '' and file_dir) or cwd
  end

  if provider == 'git' then
    local base = (file_dir ~= '' and file_dir) or cwd
    if is_git_repo(base) then
      local root = git_root(base)
      if root then return root end
    end
    -- Fallback to regular cwd
    return cwd
  end

  -- 'cwd'
  return cwd
end

function M.build_cmd(bin, sub, args, cfg)
  local cmd = { bin }
  if sub and sub ~= '' then
    table.insert(cmd, sub)
  end

  -- model override
  if cfg.model and cfg.model ~= '' then
    table.insert(cmd, '--model')
    table.insert(cmd, cfg.model)
  end


  -- extra args
  if cfg.extra_args and #cfg.extra_args > 0 then
    for _, a in ipairs(cfg.extra_args) do table.insert(cmd, a) end
  end

  -- positional args
  if args and #args > 0 then
    for _, a in ipairs(args) do table.insert(cmd, a) end
  end

  logger.debug('cmd', vim.inspect(cmd))
  return cmd
end

return M

