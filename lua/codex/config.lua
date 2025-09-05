local M = {}

M.defaults = {
  bin = "codex",           -- path to Codex CLI
  model = nil,              -- optional model override
  ask_for_approval = false, -- pass -a/--ask-for-approval
  extra_args = {},          -- additional args array, e.g. {"--full-auto"}
  env = {},                 -- environment overrides
  cwd_provider = 'git',     -- 'git' | 'cwd' | 'file'
  terminal = {
    direction = 'horizontal', -- 'horizontal' | 'vertical'
    size = 15,                -- split height/width
    reuse = true,             -- reuse terminal buffer
  },
}

M.options = {}

function M.apply(opts)
  M.options = vim.tbl_deep_extend('force', {}, M.defaults, opts or {})
  return M.options
end

return M

