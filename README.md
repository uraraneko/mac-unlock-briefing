# Unlock Briefing (Hammerspoon)

macOS 解锁后自动弹出「今日待办 + 关键倒计时」简报。基于 [Hammerspoon](https://www.hammerspoon.org/)，本地 JSON 内容、零额外权限、不抢焦点。

## 功能

| 项目 | 说明 |
|------|------|
| 触发 | 屏幕解锁（`screensDidUnlock`），可选同时支持唤醒 |
| 今日待办 + 关键倒计时 | **统一**写在 `content.json` |
| 展示 | `hs.alert` 大字中央提示，默认约 8 秒消失 |
| 行为 | 可选「当天仅第一次解锁才弹」；无内容时简单问候 |

## 配置：内容 vs 行为

| 文件 | 写什么 | 是否进 Git |
|------|--------|------------|
| **`content.json`** | **你的**待办 + 倒计时（日常只改这个） | ❌ **gitignore，不提交** |
| **`content.example.json`** | 演示模板；clone 后 `setup.sh` 会据此生成 `content.json` | ✅ 提交 |
| **`config.lua`** | 显示时长、UI、当天仅一次、热键等 | ✅ 提交 |

### 内容 — 本地 `content.json`（私有）

```bash
# 若还没有，可手动复制模板：
cp content.example.json content.json
```

```json
{
  "todos": [
    "完成报告初稿",
    "回复客户邮件"
  ],
  "countdowns": [
    { "title": "项目上线", "date": "2026-12-31" },
    { "title": "生日", "date": "2026-09-15" }
  ]
}
```

- `todos`：字符串数组  
- `countdowns`：`title` + `date`（`YYYY-MM-DD`）  
- **个人内容只写 `content.json`，不会被 git 推上去**  
- 改完 → **Reload Config** → **⌘⌃⇧B** 预览

### 行为 / UI — `config.lua`

- `showDuration`、`onlyFirstUnlockOfDay`、`alsoOnWake`、`unlockDelay`
- `alertStyle`（字体、字号、颜色、圆角、位置）
- `forceHotkey`（默认 ⌘⌃⇧B 强制预览）

## 安装（跨用户 / 跨设备可复现）

```bash
git clone <repo> && cd todo-alert-mac
./setup.sh          # 或: make setup
```

`setup.sh` 按 **`setup.config`** 安装 Hammerspoon，并软链：

`init.lua` / `config.lua` / `briefing.lua` / `content.json` → `~/.hammerspoon/`

**必须手动一次：** 系统设置 → 隐私与安全性 → **辅助功能** → 启用 Hammerspoon。  
然后：菜单栏锤子 → **Reload Config**。

## 触发与调试

| 场景 | 是否弹出 |
|------|----------|
| 当天第一次**解锁** | 是（默认） |
| 当天再解锁 | 否（`onlyFirstUnlockOfDay`） |
| **⌘⌃⇧B** | 强制弹一次 |

开发：改 `content.json` 或 `config.lua` → Reload Config → ⌘⌃⇧B。

## 开发与测试

```bash
brew install lua
make all
```

## 文件布局

```
mac-unlock-briefing/
├── init.lua               # 入口：watcher + alert
├── briefing.lua           # 纯逻辑
├── config.lua             # 行为 / UI
├── content.example.json   # 演示内容模板（提交）
├── content.json           # 你的私有内容（gitignore，不提交）
├── setup.config / setup.sh
├── tests/
└── README.md
```

## 后续可扩展

- Apple Reminders / 外部同步：写回 `content.json` 即可  
- `hs.webview` 精美卡片  
- 语音播报 `hs.speech`
