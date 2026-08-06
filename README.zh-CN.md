# mac-unlock-briefing

[English](README.md) · **中文**

macOS 解锁屏幕后，自动弹出今日待办和关键日期倒计时（基于 [Hammerspoon](https://www.hammerspoon.org/)）。

## 安装

```bash
git clone https://github.com/uraraneko/mac-unlock-briefing.git
cd mac-unlock-briefing
./setup.sh
```

1. 授予 **辅助功能** 权限：系统设置 → 隐私与安全性 → 辅助功能 → 启用 Hammerspoon  
2. 菜单栏锤子图标 → **Reload Config**  
3. 锁屏再解锁，即可看到简报  

可选：锤子菜单开启 **Launch Hammerspoon at login**。

## 配置

编辑 **`content.json`**（待办 + 倒计时）：

```json
{
  "todos": ["完成报告初稿", "回复客户邮件"],
  "countdowns": [
    { "title": "项目上线", "date": "2026-12-31" }
  ]
}
```

![Mac 解锁后显示的简报](docs/screenshots/unlock-briefing.jpg)

显示时长、样式、热键等改 **`config.lua`**。

改完后 **Reload Config**。开发调试可按 **⌘⌃⇧B** 强制弹一次。
