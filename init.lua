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

-- Currently visible briefing alert (hs.alert UUID) + auto-clear timer
local activeBriefingId = nil
local hideTimer = nil

local function jsonDecode()
  if hs and hs.json and hs.json.decode then
    return hs.json.decode
  end
  return function()
    return nil
  end
end

--- Load todos + countdowns from unified external JSON (content.json / data/content.json)
local function loadContent()
  local candidates = {}
  if config.contentFile then
    table.insert(candidates, config.contentFile)
  end
  table.insert(candidates, "data/content.json")
  table.insert(candidates, "content.json")
  table.insert(candidates, "content.json.example")

  local raw = nil
  for _, name in ipairs(candidates) do
    local path = (name:sub(1, 1) == "/") and name or (configdir .. "/" .. name)
    local file = io.open(path, "r")
    if file then
      raw = file:read("*a")
      file:close()
      if raw and raw ~= "" then
        break
      end
    end
  end

  if not raw then
    return { todos = {}, countdowns = {} }
  end
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

local function stopHideTimer()
  if hideTimer then
    pcall(function()
      hideTimer:stop()
    end)
    hideTimer = nil
  end
end

--- True while a briefing alert is still expected to be on screen.
local function isBriefingVisible()
  return activeBriefingId ~= nil
end

--- Dismiss the current briefing alert immediately (if any).
local function dismissBriefing()
  if not activeBriefingId then
    stopHideTimer()
    return false
  end
  if hs.alert and hs.alert.closeSpecific then
    hs.alert.closeSpecific(activeBriefingId)
  end
  activeBriefingId = nil
  stopHideTimer()
  return true
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

  -- Replace any still-visible briefing instead of stacking
  dismissBriefing()

  local msg = buildMessage()
  local duration = config.showDuration or 8
  local style = config.alertStyle or {
    textFont = "PingFang SC",
    textSize = 18,
    fillColor = { white = 0.1, alpha = 0.85 },
    textColor = { white = 1, alpha = 1 },
    radius = 12,
  }
  local id = hs.alert.show(msg, style, duration)
  activeBriefingId = id

  -- hs.alert auto-hides after duration; mirror that so toggle knows state
  if hs.timer and hs.timer.doAfter then
    hideTimer = hs.timer.doAfter(duration, function()
      if activeBriefingId == id then
        activeBriefingId = nil
        hideTimer = nil
      end
    end)
  end

  lastShownDate = today
  return true
end

local function forceShowBriefing()
  return showBriefing({ force = true })
end

local syncInProgress = false

--- Asynchronously sync data repository with git pull --rebase and git push
local function syncDataRepo(callback)
  if syncInProgress then
    if callback then callback(false, "sync already in progress") end
    return
  end

  local syncDirName = config.syncDir or "data"
  local targetDir = (syncDirName:sub(1, 1) == "/") and syncDirName or (configdir .. "/" .. syncDirName)

  -- Check if sync directory contains a git repository
  local gitDir = io.open(targetDir .. "/.git/HEAD", "r")
  if not gitDir then
    if callback then callback(false, "not a git repo") end
    return
  end
  gitDir:close()

  if not (hs and hs.task and hs.task.new) then
    if callback then callback(false, "hs.task unavailable") end
    return
  end

  syncInProgress = true
  local syncScript = string.format([[
    cd "%s" || exit 0
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
      git add -A && git commit -m "auto: sync $(date '+%%Y-%%m-%%d %%H:%%M:%%S')" 2>/dev/null || true
    fi
    git pull --rebase origin main 2>/dev/null || true
    git push origin main 2>/dev/null || true
  ]], targetDir)

  local task = hs.task.new("/bin/sh", function(exitCode, stdOut, stdErr)
    syncInProgress = false
    local success = (exitCode == 0)
    if callback then
      callback(success, stdOut, stdErr)
    end
  end, { "-c", syncScript })

  task:start()
end

--- ⌘⇧U (config.forceHotkey): open if hidden, close if already open.
local function toggleBriefing()
  if isBriefingVisible() then
    dismissBriefing()
    return false
  end

  local shown = forceShowBriefing()

  -- Perform background sync if enabled
  if config.autoSyncOnToggle ~= false then
    syncDataRepo(function(success)
      if success and isBriefingVisible() then
        -- Update content in place if still visible
        dismissBriefing()
        forceShowBriefing()
      end
    end)
  end

  return shown
end

local M = {
  showBriefing = showBriefing,
  forceShowBriefing = forceShowBriefing,
  toggleBriefing = toggleBriefing,
  dismissBriefing = dismissBriefing,
  isBriefingVisible = isBriefingVisible,
  buildMessage = buildMessage,
  loadContent = loadContent,
  getTodos = getTodos,
  getCountdownLines = getCountdownLines,
  syncDataRepo = syncDataRepo,
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
  local mods = config.forceHotkey.mods or { "cmd", "shift" }
  local key = config.forceHotkey.key
  forceHotkey = hs.hotkey.bind(mods, key, function()
    toggleBriefing()
  end)
  print(string.format(
    "Unlock Briefing toggle hotkey: %s + %s",
    table.concat(mods, "+"),
    key
  ))
end
M.forceHotkey = forceHotkey

hs.alert.show("每日简报已启动", 1.5)
print("Unlock Briefing loaded.")

return M
