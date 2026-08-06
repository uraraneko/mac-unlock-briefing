-- init.lua — Hammerspoon unlock briefing entry point
-- Install: copy/symlink init.lua config.lua briefing.lua content.json → ~/.hammerspoon/
-- Then: menu bar hammer → Reload Config
--
-- 内容（待办 + 倒计时）→ content.json
-- 行为 / UI → config.lua

local configdir = (hs and hs.configdir) or (os.getenv("HOME") .. "/.hammerspoon")

local config = dofile(configdir .. "/config.lua")
local briefing = dofile(configdir .. "/briefing.lua")

-- State: last calendar day we successfully showed the briefing
local lastShownDate = nil

local function jsonDecode()
  if hs and hs.json and hs.json.decode then
    return hs.json.decode
  end
  return function()
    return nil
  end
end

--- Load todos + countdowns from unified external JSON (content.json)
local function loadContent()
  local name = config.contentFile or "content.json"
  local path
  if name:sub(1, 1) == "/" then
    path = name
  else
    path = configdir .. "/" .. name
  end
  local file = io.open(path, "r")
  if not file then
    return { todos = {}, countdowns = {} }
  end
  local raw = file:read("*a")
  file:close()
  return briefing.parseContent(raw, jsonDecode())
end

local function getTodos()
  return loadContent().todos
end

local function getCountdownLines()
  return briefing.getCountdowns(loadContent().countdowns)
end

local function buildMessage()
  local content = loadContent()
  return briefing.buildMessage({
    todos = content.todos,
    countdowns = briefing.getCountdowns(content.countdowns),
  })
end

--- Show briefing.
--- @param opts table|nil
---   opts.force boolean  if true, bypass onlyFirstUnlockOfDay (for debug)
local function showBriefing(opts)
  opts = opts or {}
  local force = opts.force == true
  local today = os.date("%Y-%m-%d")
  if not force and not briefing.shouldShow(config.onlyFirstUnlockOfDay, lastShownDate, today) then
    return false
  end

  local msg = buildMessage()
  local duration = config.showDuration or 8
  local style = config.alertStyle or {
    textFont = "PingFang SC",
    textSize = 18,
    fillColor = { white = 0.1, alpha = 0.85 },
    textColor = { white = 1, alpha = 1 },
    radius = 12,
  }
  hs.alert.show(msg, style, duration)

  lastShownDate = today
  return true
end

local function forceShowBriefing()
  return showBriefing({ force = true })
end

local M = {
  showBriefing = showBriefing,
  forceShowBriefing = forceShowBriefing,
  buildMessage = buildMessage,
  loadContent = loadContent,
  getTodos = getTodos,
  getCountdownLines = getCountdownLines,
  briefing = briefing,
  config = config,
  getLastShownDate = function()
    return lastShownDate
  end,
  setLastShownDate = function(d)
    lastShownDate = d
  end,
}

local function onCaffeinateEvent(event)
  local unlock = hs.caffeinate.watcher.screensDidUnlock
  local wake = hs.caffeinate.watcher.systemDidWake
  local should = (event == unlock)
    or (config.alsoOnWake and event == wake)
  if should then
    local delay = config.unlockDelay or 0.8
    hs.timer.doAfter(delay, showBriefing)
  end
end

local watcher = hs.caffeinate.watcher.new(onCaffeinateEvent)
watcher:start()

M.watcher = watcher
M.onCaffeinateEvent = onCaffeinateEvent

local forceHotkey = nil
if type(config.forceHotkey) == "table"
  and type(config.forceHotkey.key) == "string"
  and hs.hotkey
then
  local mods = config.forceHotkey.mods or { "cmd", "ctrl", "shift" }
  local key = config.forceHotkey.key
  forceHotkey = hs.hotkey.bind(mods, key, function()
    forceShowBriefing()
  end)
  print(string.format(
    "Unlock Briefing force hotkey: %s + %s",
    table.concat(mods, "+"),
    key
  ))
end
M.forceHotkey = forceHotkey

hs.alert.show("每日简报已启动", 1.5)
print("Unlock Briefing loaded.")

return M
