# mac-unlock-briefing

**English** · [中文](README.zh-CN.md)

Show today’s todos and key-date countdowns when you unlock your Mac — powered by [Hammerspoon](https://www.hammerspoon.org/).

Native Swift app (no Hammerspoon): [unlock-briefing](https://github.com/uraraneko/unlock-briefing).

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

## Multi-device Sync (Private Repo)

Personal todos and countdowns are excluded from this public repo to protect privacy:
1. Data is loaded with priority from `~/.hammerspoon/data/content.json` (or local `content.json`).
2. Pressing **⌘⇧U** triggers a lightweight background two-way sync (`git pull --rebase` & `git push`).
3. If new changes are pulled from your private data repo, the alert preview updates immediately in place.

## Configure

Edit **`content.json`** (or `data/content.json`):

```json
{
  "todos": ["Draft the report", "Reply to email"],
  "countdowns": [{ "title": "Launch", "date": "2026-12-31" }]
}
```

![Unlock briefing shown after Mac unlock](docs/screenshots/unlock-briefing.jpg)

Display duration, style, and hotkeys: **`config.lua`**.

After changes → **Reload Config**. Press **⌘⇧U** to toggle a quick preview (open if hidden, close if already open).
