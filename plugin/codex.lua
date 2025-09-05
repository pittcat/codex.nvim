-- bootstrap commands on load for convenience if user doesn't call setup()
pcall(function()
  local codex = require('codex')
  if not codex.state or not codex.state.opts then
    codex.setup({})
  end
end)

