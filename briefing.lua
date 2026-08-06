-- briefing.lua — pure logic for unlock briefing (no live hs required)
-- Functions take data/time inputs and return strings/tables so tests can
-- drive the real shipped code with fixtures only.

local M = {}

--- Normalize a list of todo strings (drop non-strings / empty).
function M.normalizeTodos(list)
  local result = {}
  if type(list) ~= "table" then
    return result
  end
  for _, t in ipairs(list) do
    if type(t) == "string" and t ~= "" then
      table.insert(result, t)
    end
  end
  return result
end

--- Normalize countdown entries to { title, date } tables.
function M.normalizeCountdowns(list)
  local result = {}
  if type(list) ~= "table" then
    return result
  end
  for _, item in ipairs(list) do
    if type(item) == "table"
      and type(item.title) == "string"
      and item.title ~= ""
      and type(item.date) == "string"
      and item.date ~= ""
    then
      table.insert(result, { title = item.title, date = item.date })
    end
  end
  return result
end

--- Parse unified content JSON: { "todos": [...], "countdowns": [{title,date}, ...] }
--- Also accepts legacy bare array of todo strings → todos only.
---@param content string|nil raw JSON string
---@param decode fun(s: string): any JSON decode (e.g. hs.json.decode)
---@return table { todos = string[], countdowns = {title,date}[] }
function M.parseContent(content, decode)
  local empty = { todos = {}, countdowns = {} }
  if not content or content == "" or type(decode) ~= "function" then
    return empty
  end
  local ok, data = pcall(decode, content)
  if not ok or type(data) ~= "table" then
    return empty
  end
  -- Legacy: whole file is a JSON array of strings
  if data[1] ~= nil and type(data[1]) == "string" then
    return { todos = M.normalizeTodos(data), countdowns = {} }
  end
  return {
    todos = M.normalizeTodos(data.todos),
    countdowns = M.normalizeCountdowns(data.countdowns),
  }
end

--- Parse JSON todo array only (legacy helper; prefer parseContent).
---@param content string|nil raw JSON string
---@param decode fun(s: string): any
---@return table list of todo strings
function M.parseTodos(content, decode)
  return M.parseContent(content, decode).todos
end

--- Format remaining time for a single countdown item.
--- @param title string
--- @param dateStr string "YYYY-MM-DD"
--- @param now number unix timestamp (optional; defaults to os.time())
--- @return string|nil formatted line, or nil if date invalid
function M.formatCountdown(title, dateStr, now)
  if type(title) ~= "string" or type(dateStr) ~= "string" then
    return nil
  end
  local y, m, d = dateStr:match("^(%d+)%-(%d+)%-(%d+)$")
  if not y then
    return nil
  end
  now = now or os.time()
  local target = os.time({
    year = tonumber(y),
    month = tonumber(m),
    day = tonumber(d),
    hour = 0,
    min = 0,
    sec = 0,
  })
  local diff = target - now
  if diff > 0 then
    local days = math.floor(diff / 86400)
    local hours = math.floor((diff % 86400) / 3600)
    return string.format("%s：还剩 %d 天 %d 小时", title, days, hours)
  else
    return title .. "：已到期"
  end
end

--- Compute all countdown display lines from config list.
--- @param countdowns table|nil array of { title, date }
--- @param now number|nil unix timestamp
--- @return table list of formatted strings
function M.getCountdowns(countdowns, now)
  local result = {}
  if type(countdowns) ~= "table" then
    return result
  end
  for _, item in ipairs(countdowns) do
    if type(item) == "table" then
      local line = M.formatCountdown(item.title, item.date, now)
      if line then
        table.insert(result, line)
      end
    end
  end
  return result
end

--- Build greeting based on hour of day.
--- @param hour number 0-23
--- @return string
function M.greetingForHour(hour)
  hour = tonumber(hour) or 0
  if hour < 12 then
    return "早上好"
  elseif hour < 18 then
    return "下午好"
  else
    return "晚上好"
  end
end

--- Build the full briefing message.
--- @param opts table
---   opts.todos table list of strings
---   opts.countdowns table list of formatted countdown strings (pre-formatted)
---   opts.now number|nil unix time for date/hour (default os.time())
---   opts.dateLabel string|nil override date label (for tests)
--- @return string
function M.buildMessage(opts)
  opts = opts or {}
  local todos = opts.todos or {}
  local cds = opts.countdowns or {}
  local now = opts.now or os.time()
  local hour = tonumber(os.date("%H", now))
  local greeting = M.greetingForHour(hour)
  local dateLabel = opts.dateLabel or os.date("%Y年%m月%d日", now)

  if #todos == 0 and #cds == 0 then
    return greeting .. "！今天暂无特别安排，保持专注。"
  end

  local lines = {}
  table.insert(lines, greeting .. "！今天是 " .. dateLabel)

  if #todos > 0 then
    table.insert(lines, "")
    table.insert(lines, "【今日待办】")
    for i, t in ipairs(todos) do
      table.insert(lines, string.format("%d. %s", i, t))
    end
  end

  if #cds > 0 then
    table.insert(lines, "")
    table.insert(lines, "【关键倒计时】")
    for _, c in ipairs(cds) do
      table.insert(lines, "• " .. c)
    end
  end

  return table.concat(lines, "\n")
end

--- First-of-day gate: should we show the briefing?
--- @param onlyFirst boolean config.onlyFirstUnlockOfDay
--- @param lastShownDate string|nil "YYYY-MM-DD" of last successful show
--- @param today string "YYYY-MM-DD"
--- @return boolean true if should show
function M.shouldShow(onlyFirst, lastShownDate, today)
  if onlyFirst and lastShownDate == today then
    return false
  end
  return true
end

return M
