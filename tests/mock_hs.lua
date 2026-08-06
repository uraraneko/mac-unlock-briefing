-- Minimal hs mock for loading init.lua outside Hammerspoon

local M = {}

M.configdir = nil -- set by harness
M._alerts = {}
M._timers = {}
M._watcher_started = false
M._watcher_callback = nil
M._json_decode = nil -- optional override
M._hotkeys = {}

function M.reset()
  M._alerts = {}
  M._timers = {}
  M._watcher_started = false
  M._watcher_callback = nil
  M._hotkeys = {}
end

M.alert = {
  show = function(msg, style_or_duration, duration)
    local d = duration
    if type(style_or_duration) == "number" then
      d = style_or_duration
    end
    table.insert(M._alerts, { msg = msg, duration = d, style = style_or_duration })
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
    table.insert(M._timers, { delay = delay, fn = fn })
    if type(fn) == "function" then
      fn()
    end
  end,
}

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
