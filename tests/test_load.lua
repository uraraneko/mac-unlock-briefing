-- Load harness: dofile init.lua under mock hs, simulate unlock
-- Run: lua tests/test_load.lua

local function script_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then
    src = src:sub(2)
  end
  return src:match("(.*/)") or "./"
end

local DIR = script_dir()
local REPO = DIR .. "../"

-- Normalize absolute-ish path for package / dofile
local function abspath(p)
  local f = io.popen('cd "' .. p:gsub('"$', "") .. '" && pwd')
  if f then
    local out = f:read("*l")
    f:close()
    if out and out ~= "" then
      return out
    end
  end
  return p
end

REPO = abspath(REPO) .. "/"

package.path = REPO .. "?.lua;" .. REPO .. "tests/?.lua;" .. package.path

local mock = dofile(REPO .. "tests/mock_hs.lua")
mock.configdir = REPO:gsub("/$", "") -- init uses configdir without trailing slash ideally
-- config files live at REPO root; set configdir to REPO root
mock.configdir = REPO:sub(1, -2) -- strip trailing /

mock.reset()
_G.hs = mock

print("Loading init.lua from " .. REPO .. "init.lua")
print("hs.configdir = " .. hs.configdir)

local ok, mod_or_err = pcall(dofile, REPO .. "init.lua")
if not ok then
  print("LOAD FAIL: " .. tostring(mod_or_err))
  os.exit(1)
end

local mod = mod_or_err
print("Load OK, type(mod)=" .. type(mod))

-- Startup alert should have fired
local startup_alerts = #mock._alerts
print("Alerts after load: " .. startup_alerts)
if startup_alerts < 1 then
  print("FAIL: expected startup alert")
  os.exit(1)
end
print("  startup msg: " .. tostring(mock._alerts[1].msg))

if not mock._watcher_started then
  print("FAIL: watcher not started")
  os.exit(1)
end
print("Watcher started: true")

if type(mock._watcher_callback) ~= "function" then
  print("FAIL: no watcher callback")
  os.exit(1)
end

-- Simulate screensDidUnlock
mock._alerts = {} -- clear startup alerts to observe briefing only
mod.setLastShownDate(nil) -- ensure gate allows show

mock._watcher_callback(hs.caffeinate.watcher.screensDidUnlock)

if #mock._alerts < 1 then
  print("FAIL: unlock did not trigger hs.alert.show")
  print("timers fired: " .. #mock._timers)
  os.exit(1)
end

local briefing_msg = mock._alerts[#mock._alerts].msg
print("Briefing alert duration: " .. tostring(mock._alerts[#mock._alerts].duration))
print("Briefing message length: " .. #tostring(briefing_msg))
print("--- message start ---")
print(briefing_msg)
print("--- message end ---")

if not briefing_msg or briefing_msg == "" then
  print("FAIL: empty briefing message")
  os.exit(1)
end

-- With sample fixtures, expect todos or countdowns content
local has_todo = tostring(briefing_msg):find("待办") or tostring(briefing_msg):find("完成报告")
local has_cd = tostring(briefing_msg):find("倒计时") or tostring(briefing_msg):find("还剩")
if not (has_todo or has_cd) then
  print("FAIL: message missing todos/countdown content from fixtures")
  os.exit(1)
end

-- First-of-day: second unlock same day should not alert again
mock._alerts = {}
mock._watcher_callback(hs.caffeinate.watcher.screensDidUnlock)
if #mock._alerts ~= 0 then
  print("FAIL: onlyFirstUnlockOfDay should suppress second show; got " .. #mock._alerts)
  os.exit(1)
end
print("Second unlock same day suppressed: OK")

-- Config-driven duration on first show was 8
-- (we already cleared; re-show by resetting day)
mod.setLastShownDate(nil)
mock._alerts = {}
mod.showBriefing()
local d = mock._alerts[1] and mock._alerts[1].duration
if d ~= 8 then
  print("FAIL: expected showDuration 8, got " .. tostring(d))
  os.exit(1)
end
print("showDuration from config: " .. tostring(d))

-- Force show bypasses onlyFirstUnlockOfDay (same day already marked)
mock._alerts = {}
local forced = mod.forceShowBriefing()
if not forced or #mock._alerts < 1 then
  print("FAIL: forceShowBriefing should show even after first-of-day consumed")
  os.exit(1)
end
print("forceShowBriefing bypassed gate: OK")

-- Hotkey should be bound when config.forceHotkey is set
if #mock._hotkeys < 1 then
  print("FAIL: expected force hotkey binding")
  os.exit(1)
end
print("force hotkey bound: " .. table.concat(mock._hotkeys[1].mods, "+") .. "+" .. mock._hotkeys[1].key)

print("")
print("LOAD HARNESS PASSED")
os.exit(0)
