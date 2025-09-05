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
  -- initialize logger with configured level
  pcall(logger.setup, M.state.opts)
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
    position = tcfg.position,
    provider = tcfg.provider or 'native',
    auto_insert = tcfg.auto_insert_mode ~= false,
    fix_display_corruption = tcfg.fix_display_corruption == true,
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
  logger.debug('open', 'cwd =', cwd)
  run_in_terminal(cmd, cwd)
end

function M.toggle()
  -- Check if we have any active terminal
  local bufnr = term.get_active_terminal_bufnr()
  if not bufnr then
    -- No terminal exists, open one like CodexOpen
    logger.debug('toggle', 'No terminal exists, opening new terminal')
    M.open()
  else
    -- Terminal exists, toggle it
    logger.debug('toggle', 'Terminal exists, toggling visibility')
    term.simple_toggle()
  end
end



function M._create_commands()
  vim.api.nvim_create_user_command('CodexOpen', function(o)
    local arg = o.args ~= '' and o.args or nil
    M.open(arg)
  end, { nargs = '*', desc = 'Open Codex TUI with optional prompt' })

  vim.api.nvim_create_user_command('CodexToggle', function()
    M.toggle()
  end, { desc = 'Toggle Codex terminal split' })


end

return M
