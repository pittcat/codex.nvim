-- Minimal init for headless testing
-- Append plugin root to runtimepath
local fn = vim.fn
local plugin_root = fn.fnamemodify(fn.expand("<sfile>:p"), ":h:h")
vim.opt.runtimepath:append(plugin_root)

-- Silence UI prompts in headless
vim.ui.input = function(opts, on_confirm)
  if on_confirm then on_confirm("") end
end

