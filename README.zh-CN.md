# codex.nvim

轻量级 Neovim 集成 OpenAI Codex CLI：在终端分屏中打开 Codex TUI，并支持“任务完成提醒”。

- 代码仓库结构与测试说明见 `README.md`。
- 系统通知（带提示音）目前优先使用 macOS 的 `terminal-notifier`，若不可用则回退到 `osascript`，再回退到 `vim.notify`（无系统声音）。

## 快速开始

```lua
require('codex').setup()

-- 推荐映射
vim.keymap.set('n', '<leader>co', function() require('codex').open() end, { desc = 'Codex: Open TUI' })
vim.keymap.set('n', '<leader>ct', function() require('codex').toggle() end, { desc = 'Codex: Toggle terminal' })
```

## 日志

```lua
require('codex').setup({
  log_level = 'info',          -- 'trace'|'debug'|'info'|'warn'|'error'
  log_to_file = false,         -- 写入日志文件（默认 false）
})
```

## 终端选项

- `direction`: 'horizontal' | 'vertical'
- `size`: 行/列数量；0<大小<1 表示当前窗口的比例
- `position`: 'left' | 'right' | 'top' | 'bottom'
- `provider`: 'native' | 'snacks' | 'auto'
- `reuse`: 是否复用已有终端缓冲区
- `auto_insert_mode`: 打开后进入插入模式

## 完成提醒（系统通知 + 声音）

codex.nvim 提供两种提醒模式，建议二选一：

- `alert_on_idle = true`: 当终端输出进入“空闲”（不再产生新文本）时提醒；适合 Codex TUI 常驻，任务跑完也不退出的情况。
- `alert_on_exit = true`: 当任务进程退出时提醒。

示例：

```lua
require('codex').setup({
  -- 二选一
  alert_on_idle = true,
  -- alert_on_exit = true,

  notification = {
    enabled = true,              -- 开启系统通知
    sound = 'Glass',             -- macOS 系统通知声音名
    include_project_path = true, -- 在消息中包含项目路径
    speak = false,               -- 关闭语音播报（默认 false）
    backend = 'terminal-notifier', -- 优先使用 terminal-notifier
    terminal_notifier = {
      ignore_dnd = true,           -- 传递 -ignoreDnD
      sender = 'com.apple.Terminal',
      group = 'codex.nvim',
      activate = 'com.apple.Terminal',
    },

    -- 仅在 alert_on_idle=true 时生效
    idle = {
      check_interval = 1500,     -- 采样间隔（毫秒）
      idle_checks = 3,           -- 连续无变化的采样次数
      lines_to_check = 40,       -- 用于哈希比对的尾部行数
      require_activity = true,   -- 先观察到有输出再允许判定空闲
      min_change_ticks = 3,      -- 至少观察到 N 次变化再允许判定
    },
  },
})
```

### 行为说明

- macOS：优先使用 `terminal-notifier` 发送系统横幅与声音；若不可用则回退到 `osascript`；再不行回退到 `vim.notify`（无系统声音）。
- 其他平台：回退为 `vim.notify`（没有系统声音）。
- 空闲提醒（alert_on_idle）：一次性提醒，提醒后停止监控；下次再次运行 Codex 会自动重新开启监控。
- 退出提醒（alert_on_exit）：短时间内的重复成功提醒会自动去重（例如 idle 与 exit 同时触发时只发一次）。
- 空闲提醒抑制：若终端尾部文本包含取消标记（如“Request interrupted by user”、“Canceled”、“取消”），则不发送完成提醒。可通过 `notification.idle.cancel_markers` 配置。
  - 默认已包含：“🖐  Tell the model what to do differently” 以及不带表情的纯文本版本。

### 参数解释（idle）

- `check_interval`（毫秒）：多长时间取一次终端尾部文本做哈希。
- `idle_checks`：连续多少次哈希一致判定为空闲。
- `lines_to_check`：取终端尾部多少行作为比较内容。
- `require_activity`：是否必须先看到输出变化再允许空闲判定。
- `min_change_ticks`：至少观察到 N 次变化后，才允许将后续静默视为完成。

## 平台说明

- macOS：完整支持系统通知与声音；可选语音播报（默认关闭）。
- 其他系统：回退到 `vim.notify`。如需系统级声音与横幅，可自行扩展通知实现（欢迎 PR）。

## 测试

- 运行：`make test`（无需安装真实 Codex CLI，测试使用 `echo` 代替）。

## 故障排查

- 看不到系统通知或声音：
  - 检查 `osascript` 是否可用（`which osascript`）。
  - `notification.enabled` 是否为 `true`，`sound` 是否有效。
- 提醒过早：适当增大 `idle_checks` 或 `min_change_ticks`，或增大 `check_interval`。
- 想更快提醒：降低 `check_interval` 或 `idle_checks`（注意误报风险）。
