local ok, codex = pcall(require, 'codex')
if not ok then
  vim.api.nvim_err_writeln('Failed to require codex: ' .. tostring(codex))
  os.exit(1)
end

local function assert_ok(title, f)
  local ok, err = pcall(f)
  if not ok then
    vim.api.nvim_err_writeln(title .. ' failed: ' .. tostring(err))
    os.exit(1)
  end
end

-- Configure to avoid needing real Codex binary
codex.setup({
  bin = 'echo',
  extra_args = { 'TEST' },
  terminal = { reuse = false },
})

assert_ok('open', function()
  codex.open('hello')
end)

assert_ok('toggle', function()
  codex.toggle()
end)

print('codex.nvim basic tests passed')

-- Quit after a short delay to let jobs spawn
vim.defer_fn(function()
  vim.cmd('qall!')
end, 50)
