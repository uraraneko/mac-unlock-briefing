# mac-unlock-briefing

**English** · [中文](README.zh-CN.md)

Show today’s todos and key-date countdowns when you unlock your Mac — powered by [Hammerspoon](https://www.hammerspoon.org/).

## Install

```bash
git clone https://github.com/uraraneko/mac-unlock-briefing.git
cd mac-unlock-briefing
./setup.sh
```

1. Grant **Accessibility** access: System Settings → Privacy & Security → Accessibility → enable Hammerspoon
2. Menu bar hammer icon → **Reload Config**
3. Lock the screen, unlock again — the briefing appears

Optional: hammer menu → **Launch Hammerspoon at login**.

## Configure

Edit **`content.json`** (todos + countdowns):

```json
{
  "todos": ["Draft the report", "Reply to email"],
  "countdowns": [{ "title": "Launch", "date": "2026-12-31" }]
}
```

![Unlock briefing shown after Mac unlock](docs/screenshots/unlock-briefing.jpg)

Display duration, style, and hotkeys: **`config.lua`**.

After changes → **Reload Config**. For a quick preview while developing, press **⌘⇧U**.
