-- Minimal hs mock for loading init.lua outside Hammerspoon

local M = {}

M.configdir = nil -- set by harness
M._alerts = {}
M._closed = {}
M._timers = {}
M._watcher_started = false
M._watcher_callback = nil
M._json_decode = nil -- optional override
M._hotkeys = {}
M._alert_seq = 0
-- When true (default), short doAfter delays (unlock settle) fire immediately so
-- existing unlock tests stay simple. Long delays (alert showDuration hide trackers)
-- are left pending — fire with fireNextTimer() if a test needs them.
M._auto_fire_timers = true
M._auto_fire_max_delay = 2

function M.reset()
  M._alerts = {}
  M._closed = {}
  M._timers = {}
  M._watcher_started = false
  M._watcher_callback = nil
  M._hotkeys = {}
  M._alert_seq = 0
  M._auto_fire_timers = true
  M._auto_fire_max_delay = 2
end

M.alert = {
  show = function(msg, style_or_duration, duration)
    local d = duration
    if type(style_or_duration) == "number" then
      d = style_or_duration
    end
    M._alert_seq = M._alert_seq + 1
    local id = "alert-" .. tostring(M._alert_seq)
    table.insert(M._alerts, { id = id, msg = msg, duration = d, style = style_or_duration })
    return id
  end,
  closeSpecific = function(id)
    table.insert(M._closed, id)
  end,
  closeAll = function()
    table.insert(M._closed, "*")
  end,
}

-- Schema-aware JSON decode enough for content.json + legacy todo arrays
local function decode_json(s)
  if type(s) ~= "string" then
    error("json decode expects string")
  end
  -- Bare array of strings (legacy todos.json)
  if s:match("^%s*%[") and not s:match('"todos"') then
    local result = {}
    local inner = s:match("^%s*%[(.*)%]%s*$")
    if not inner then
      error("not a JSON array")
    end
    for quoted in inner:gmatch('"([^"]*)"') do
      table.insert(result, quoted)
    end
    return result
  end

  -- Unified content object { "todos": [...], "countdowns": [{title,date}, ...] }
  local data = { todos = {}, countdowns = {} }
  local todos_inner = s:match('"todos"%s*:%s*%[([^%]]*)%]')
  if todos_inner then
    for quoted in todos_inner:gmatch('"([^"]*)"') do
      table.insert(data.todos, quoted)
    end
  end
  -- title then date (with optional whitespace/newlines)
  for title, date in s:gmatch('"title"%s*:%s*"([^"]*)"%s*,%s*"date"%s*:%s*"([^"]*)"') do
    table.insert(data.countdowns, { title = title, date = date })
  end
  -- date then title
  for date, title in s:gmatch('"date"%s*:%s*"([^"]*)"%s*,%s*"title"%s*:%s*"([^"]*)"') do
    table.insert(data.countdowns, { title = title, date = date })
  end
  return data
end

M.json = {
  decode = function(s)
    if M._json_decode then
      return M._json_decode(s)
    end
    return decode_json(s)
  end,
}

M.timer = {
  doAfter = function(delay, fn)
    local entry = {
      delay = delay,
      fn = fn,
      _stopped = false,
      _fired = false,
    }
    function entry:stop()
      self._stopped = true
    end
    function entry:fire()
      if self._stopped or self._fired then
        return false
      end
      self._fired = true
      if type(self.fn) == "function" then
        self.fn()
      end
      return true
    end
    table.insert(M._timers, entry)
    local maxd = M._auto_fire_max_delay or 2
    if M._auto_fire_timers and type(delay) == "number" and delay <= maxd then
      entry:fire()
    end
    return entry
  end,
}

--- Fire the next unfired, unstopped timer (for tests with _auto_fire_timers = false).
function M.fireNextTimer()
  for _, t in ipairs(M._timers) do
    if not t._stopped and not t._fired then
      return t:fire()
    end
  end
  return false
end

M.caffeinate = {
  watcher = {
    screensDidUnlock = "screensDidUnlock",
    systemDidWake = "systemDidWake",
    new = function(cb)
      M._watcher_callback = cb
      return {
        start = function()
          M._watcher_started = true
        end,
        stop = function()
          M._watcher_started = false
        end,
      }
    end,
  },
}

M.hotkey = {
  bind = function(mods, key, fn)
    local hk = { mods = mods, key = key, fn = fn }
    table.insert(M._hotkeys, hk)
    return {
      delete = function() end,
      enable = function() end,
      disable = function() end,
    }
  end,
}

return M
