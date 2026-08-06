# mac-unlock-briefing

macOS 解锁屏幕后，自动弹出今日待办和关键日期倒计时（基于 [Hammerspoon](https://www.hammerspoon.org/)）。

## 使用

```bash
git clone https://github.com/uraraneko/mac-unlock-briefing.git
cd mac-unlock-briefing
./setup.sh
```

1. 按提示授予 **辅助功能** 权限（系统设置 → 隐私与安全性 → 辅助功能 → Hammerspoon）
2. 菜单栏锤子图标 → **Reload Config**
3. 锁屏再解锁，即可看到简报

可选：锤子菜单开启 **Launch Hammerspoon at login**。

## 改内容

编辑 **`content.json`**（待办 + 倒计时都在这里）：

```json
{
  "todos": ["完成报告初稿", "回复客户邮件"],
  "countdowns": [
    { "title": "项目上线", "date": "2026-12-31" }
  ]
}
```

显示时长、样式等改 **`config.lua`**。

改完后 **Reload Config**。调试可按 **⌘⌃⇧B** 强制弹一次。
