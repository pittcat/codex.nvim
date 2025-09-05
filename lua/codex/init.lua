local logger = require('codex.logger')
local config = require('codex.config')
local utils  = require('codex.utils')
local term   = require('codex.terminal')

local M = {}

M.state = {
  opts = config.defaults,
}

---Setup codex.nvim
---@param opts table
function M.setup(opts)
  M.state.opts = config.apply(opts)
  logger.info('setup', 'codex.nvim initialized')
  M._create_commands()
  return M
end

local function base_env(env)
  local merged = {}
  for k,v in pairs(env or {}) do merged[k] = v end
  return merged
end

local function run_in_terminal(cmd, cwd)
  local tcfg = M.state.opts.terminal or {}
  local env = base_env(M.state.opts.env)
  return term.run(cmd, {
    direction = tcfg.direction or 'horizontal',
    size = tcfg.size or 15,
    reuse = tcfg.reuse ~= false,
    cwd = cwd,
    env = env,
  })
end

---Open Codex TUI (optionally with initial prompt)
---@param prompt string|nil
function M.open(prompt)
  local cfg = M.state.opts
  local cwd = utils.get_cwd(cfg.cwd_provider)
  local args = {}
  if prompt and prompt ~= '' then table.insert(args, prompt) end
  local cmd = utils.build_cmd(cfg.bin, nil, args, cfg)
  run_in_terminal(cmd, cwd)
end

function M.toggle()
  term.simple_toggle()
end

---Run non-interactive exec with a prompt
---@param prompt string
function M.exec(prompt)
  if not prompt or prompt == '' then
    logger.warn('exec', 'Empty prompt')
    return
  end
  local cfg = M.state.opts
  local cwd = utils.get_cwd(cfg.cwd_provider)
  local cmd = utils.build_cmd(cfg.bin, 'exec', { prompt }, cfg)
  run_in_terminal(cmd, cwd)
end

---Prompt user for input then run codex exec
function M.ask()
  vim.ui.input({ prompt = 'Codex prompt: ' }, function(input)
    if not input or input == '' then return end
    M.exec(input)
  end)
end

---Use visual selection content for codex exec
function M.exec_visual()
  local mode = vim.fn.mode()
  if not mode:match('[vV\22]') then
    logger.warn('visual', 'No visual selection; falling back to :CodexAsk')
    return M.ask()
  end
  local srow = vim.fn.line("'<")
  local erow = vim.fn.line("'>")
  local lines = vim.api.nvim_buf_get_lines(0, srow-1, erow, false)
  local text = table.concat(lines, '\n')
  local prompt = 'Please consider this selection and respond accordingly:\n\n' .. text
  M.exec(prompt)
end

function M._create_commands()
  vim.api.nvim_create_user_command('CodexOpen', function(o)
    local arg = o.args ~= '' and o.args or nil
    M.open(arg)
  end, { nargs = '*', desc = 'Open Codex TUI with optional prompt' })

  vim.api.nvim_create_user_command('CodexToggle', function()
    M.toggle()
  end, { desc = 'Toggle Codex terminal split' })

  vim.api.nvim_create_user_command('CodexExec', function(o)
    if o.args == '' then
      return M.ask()
    end
    M.exec(o.args)
  end, { nargs = '*', desc = 'Run codex exec with a prompt' })

  vim.api.nvim_create_user_command('CodexAsk', function()
    M.ask()
  end, { desc = 'Prompt for input then run codex exec' })

  vim.api.nvim_create_user_command('CodexExecVisual', function()
    M.exec_visual()
  end, { range = true, desc = 'Run codex exec with visual selection' })
end

return M
