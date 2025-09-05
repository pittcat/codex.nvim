-- Ensure user commands execute without error in headless mode
require('codex').setup({
  bin = 'echo',
  extra_args = { 'CMD' },
  terminal = { reuse = false },
})

local function assert_cmd(cmd)
  local ok, err = pcall(vim.cmd, cmd)
  if not ok then
    vim.api.nvim_err_writeln('Command failed: ' .. cmd .. ' -> ' .. tostring(err))
    os.exit(1)
  end
end

assert_cmd('CodexOpen hello')


print('codex.nvim command tests passed')
vim.defer_fn(function() vim.cmd('qall!') end, 50)
