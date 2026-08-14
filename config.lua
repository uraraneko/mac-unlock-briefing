-- config.lua — 应用行为 / UI 设置（不含待办与倒计时内容）
-- 内容统一写在 content.json（见 contentFile）
-- Copy or symlink into ~/.hammerspoon/ alongside init.lua

return {
  -- 内容文件（相对 hs.configdir / 仓库根，或绝对路径）
  -- 优先读取 data/content.json（若配置了私有同步库），兜底读取 content.json
  contentFile = "data/content.json",

  -- 是否在 ⌘⇧U 弹窗时自动执行后台双向同步（git pull --rebase & git push）
  autoSyncOnToggle = true,

  -- 数据同步目录（相对 hs.configdir 或绝对路径）
  syncDir = "data",

  -- Display duration in seconds
  showDuration = 8,

  -- When true, only show on the first *unlock* of each calendar day
  onlyFirstUnlockOfDay = true,

  -- Optional: also show on system wake (in addition to screensDidUnlock)
  alsoOnWake = false,

  -- Delay after unlock before showing (seconds); lets the screen settle
  unlockDelay = 0.8,

  -- ---------------------------------------------------------------------------
  -- UI：hs.alert 外观（改这里 → Reload Config → ⌘⇧U 切换预览）
  -- ---------------------------------------------------------------------------
  alertStyle = {
    textFont = "PingFang SC",
    textSize = 18,
    fillColor = { white = 0.1, alpha = 0.85 },
    textColor = { white = 1, alpha = 1 },
    strokeColor = { white = 1, alpha = 0.15 },
    strokeWidth = 1,
    radius = 12,
    atScreenEdge = 0,
    fadeInDuration = 0.15,
    fadeOutDuration = 0.15,
  },

  -- ---------------------------------------------------------------------------
  -- Debug / force show
  -- ---------------------------------------------------------------------------
  forceHotkey = {
    mods = { "cmd", "shift" },
    key = "u",
  },
}
