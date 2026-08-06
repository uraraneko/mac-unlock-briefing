-- Unit tests for pure briefing logic (drives real shipped functions)
-- Run: lua tests/test_briefing.lua

local root = arg[0]:match("(.*/)") or "./"
package.path = root .. "../?.lua;" .. package.path

-- Resolve repo root relative to this file
local function script_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then
    src = src:sub(2)
  end
  return src:match("(.*/)") or "./"
end

local DIR = script_dir()
local REPO = DIR .. "../"
package.path = REPO .. "?.lua;" .. package.path

local briefing = dofile(REPO .. "briefing.lua")

local passed = 0
local failed = 0
local failures = {}

local function assert_eq(actual, expected, name)
  if actual == expected then
    passed = passed + 1
    print("  PASS  " .. name)
  else
    failed = failed + 1
    local msg = string.format("%s\n    expected: %q\n    actual:   %q", name, tostring(expected), tostring(actual))
    table.insert(failures, msg)
    print("  FAIL  " .. name)
    print("    expected: " .. tostring(expected))
    print("    actual:   " .. tostring(actual))
  end
end

local function assert_true(cond, name)
  if cond then
    passed = passed + 1
    print("  PASS  " .. name)
  else
    failed = failed + 1
    table.insert(failures, name)
    print("  FAIL  " .. name)
  end
end

local function assert_match(str, pattern, name)
  if type(str) == "string" and str:find(pattern) then
    passed = passed + 1
    print("  PASS  " .. name)
  else
    failed = failed + 1
    local msg = string.format("%s\n    pattern: %s\n    str: %s", name, pattern, tostring(str))
    table.insert(failures, msg)
    print("  FAIL  " .. name)
  end
end

-- Minimal JSON decode matching what init uses (array of strings)
local function simple_json_decode(s)
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

-- Content-object decoder used by unit tests (mirrors mock_hs enough for fixtures)
local function content_json_decode(s)
  if s:match("^%s*%[") and not s:match('"todos"') then
    return simple_json_decode(s)
  end
  local data = { todos = {}, countdowns = {} }
  local todos_inner = s:match('"todos"%s*:%s*%[([^%]]*)%]')
  if todos_inner then
    for quoted in todos_inner:gmatch('"([^"]*)"') do
      table.insert(data.todos, quoted)
    end
  end
  for title, date in s:gmatch('"title"%s*:%s*"([^"]*)"%s*,%s*"date"%s*:%s*"([^"]*)"') do
    table.insert(data.countdowns, { title = title, date = date })
  end
  return data
end

print("=== parseContent (unified JSON) ===")
do
  local raw = [[{
    "todos": ["完成报告初稿", "回复客户邮件"],
    "countdowns": [
      { "title": "项目上线", "date": "2026-08-20" },
      { "title": "生日", "date": "2026-09-15" }
    ]
  }]]
  local c = briefing.parseContent(raw, content_json_decode)
  assert_eq(#c.todos, 2, "parses two todos from content.json shape")
  assert_eq(c.todos[1], "完成报告初稿", "first todo text")
  assert_eq(#c.countdowns, 2, "parses two countdowns")
  assert_eq(c.countdowns[1].title, "项目上线", "countdown title")
  assert_eq(c.countdowns[1].date, "2026-08-20", "countdown date")

  assert_eq(#briefing.parseContent(nil, content_json_decode).todos, 0, "nil content -> empty todos")
  assert_eq(#briefing.parseContent("", content_json_decode).todos, 0, "empty content -> empty")
  assert_eq(#briefing.parseContent("not json", content_json_decode).todos, 0, "invalid json -> empty")
  assert_eq(#briefing.parseContent(raw, nil).todos, 0, "nil decode -> empty")

  -- legacy bare array still works via parseTodos / parseContent
  local legacy = briefing.parseContent('["a", "b"]', simple_json_decode)
  assert_eq(#legacy.todos, 2, "legacy array -> todos")
  assert_eq(#legacy.countdowns, 0, "legacy array -> no countdowns")
end

print("=== parseTodos (legacy) ===")
do
  local todos = briefing.parseTodos('["完成报告初稿", "回复客户邮件"]', simple_json_decode)
  assert_eq(#todos, 2, "parses two todos")
  assert_eq(todos[1], "完成报告初稿", "first todo text")
  assert_eq(todos[2], "回复客户邮件", "second todo text")

  assert_eq(#briefing.parseTodos(nil, simple_json_decode), 0, "nil content -> empty")
  assert_eq(#briefing.parseTodos("", simple_json_decode), 0, "empty content -> empty")
  assert_eq(#briefing.parseTodos("not json", simple_json_decode), 0, "invalid json -> empty")
  assert_eq(#briefing.parseTodos('["a"]', nil), 0, "nil decode -> empty")
  assert_eq(#briefing.parseTodos('[]', simple_json_decode), 0, "empty array -> empty")
end

print("=== formatCountdown ===")
do
  -- Fixed "now": 2026-08-05 12:00:00 local
  local now = os.time({ year = 2026, month = 8, day = 5, hour = 12, min = 0, sec = 0 })

  local future = briefing.formatCountdown("项目上线", "2026-08-20", now)
  assert_match(future, "项目上线：还剩", "future has title and 还剩")
  assert_match(future, "%d+ 天", "future has days")
  assert_match(future, "%d+ 小时", "future has hours")

  -- 2026-08-20 00:00 - 2026-08-05 12:00 = 14 days 12 hours
  local days = math.floor((os.time({ year = 2026, month = 8, day = 20, hour = 0 }) - now) / 86400)
  local hours = math.floor(((os.time({ year = 2026, month = 8, day = 20, hour = 0 }) - now) % 86400) / 3600)
  local expected = string.format("项目上线：还剩 %d 天 %d 小时", days, hours)
  assert_eq(future, expected, "exact remaining days/hours for 项目上线")

  local past = briefing.formatCountdown("考试", "2026-01-01", now)
  assert_eq(past, "考试：已到期", "past date -> 已到期")

  assert_eq(briefing.formatCountdown("x", "bad-date", now), nil, "invalid date -> nil")
  assert_eq(briefing.formatCountdown(nil, "2026-01-01", now), nil, "nil title -> nil")
end

print("=== getCountdowns ===")
do
  local now = os.time({ year = 2026, month = 8, day = 5, hour = 12, min = 0, sec = 0 })
  local lines = briefing.getCountdowns({
    { title = "生日", date = "2026-09-15" },
    { title = "过期", date = "2020-01-01" },
  }, now)
  assert_eq(#lines, 2, "two countdown lines")
  assert_match(lines[1], "生日：还剩", "first is birthday remaining")
  assert_eq(lines[2], "过期：已到期", "second is expired")
  assert_eq(#briefing.getCountdowns(nil, now), 0, "nil list -> empty")
  assert_eq(#briefing.getCountdowns({}, now), 0, "empty list -> empty")
end

print("=== greetingForHour ===")
do
  assert_eq(briefing.greetingForHour(8), "早上好", "morning")
  assert_eq(briefing.greetingForHour(14), "下午好", "afternoon")
  assert_eq(briefing.greetingForHour(20), "晚上好", "evening")
  assert_eq(briefing.greetingForHour(0), "早上好", "midnight morning")
  assert_eq(briefing.greetingForHour(11), "早上好", "11 morning")
  assert_eq(briefing.greetingForHour(12), "下午好", "12 afternoon")
  assert_eq(briefing.greetingForHour(17), "下午好", "17 afternoon")
  assert_eq(briefing.greetingForHour(18), "晚上好", "18 evening")
end

print("=== buildMessage ===")
do
  local now = os.time({ year = 2026, month = 8, day = 5, hour = 9, min = 0, sec = 0 })

  local empty = briefing.buildMessage({ todos = {}, countdowns = {}, now = now })
  assert_match(empty, "早上好", "empty uses morning greeting")
  assert_match(empty, "今天暂无特别安排", "empty quiet message")
  assert_true(not empty:find("【今日待办】"), "empty has no todo section")
  assert_true(not empty:find("【关键倒计时】"), "empty has no countdown section")

  local full = briefing.buildMessage({
    todos = { "完成报告初稿", "回复客户邮件" },
    countdowns = { "项目上线：还剩 14 天 12 小时" },
    now = now,
    dateLabel = "2026年08月05日",
  })
  assert_match(full, "早上好！今天是 2026年08月05日", "header with date")
  assert_match(full, "【今日待办】", "has todo section")
  assert_match(full, "1%. 完成报告初稿", "todo 1")
  assert_match(full, "2%. 回复客户邮件", "todo 2")
  assert_match(full, "【关键倒计时】", "has countdown section")
  assert_match(full, "• 项目上线：还剩 14 天 12 小时", "countdown bullet")

  local todosOnly = briefing.buildMessage({
    todos = { "唯一待办" },
    countdowns = {},
    now = now,
  })
  assert_match(todosOnly, "【今日待办】", "todos only has section")
  assert_true(not todosOnly:find("【关键倒计时】"), "todos only no countdown section")

  local cdsOnly = briefing.buildMessage({
    todos = {},
    countdowns = { "生日：还剩 1 天 0 小时" },
    now = now,
  })
  assert_match(cdsOnly, "【关键倒计时】", "cds only has section")
  assert_true(not cdsOnly:find("【今日待办】"), "cds only no todo section")
end

print("=== shouldShow (first-of-day gate) ===")
do
  assert_true(briefing.shouldShow(true, nil, "2026-08-05"), "first unlock of day shows")
  assert_true(not briefing.shouldShow(true, "2026-08-05", "2026-08-05"), "same day suppressed")
  assert_true(briefing.shouldShow(true, "2026-08-04", "2026-08-05"), "new day shows")
  assert_true(briefing.shouldShow(false, "2026-08-05", "2026-08-05"), "flag off always shows")
  assert_true(briefing.shouldShow(false, nil, "2026-08-05"), "flag off with nil last")
  -- Note: force path lives in init.showBriefing({force=true}); gate itself only cares about onlyFirst
end

print("=== sample fixtures from repo ===")
do
  -- content.json is gitignored; tests use committed content.example.json
  local f = io.open(REPO .. "content.example.json", "r")
  assert_true(f ~= nil, "content.example.json exists")
  local raw = f:read("*a")
  f:close()
  local content = briefing.parseContent(raw, content_json_decode)
  assert_true(#content.todos >= 1, "example has at least one todo")
  assert_eq(content.todos[1], "完成报告初稿", "example first todo")
  assert_true(#content.countdowns >= 1, "example has countdowns")
  local lines = briefing.getCountdowns(
    content.countdowns,
    os.time({ year = 2026, month = 8, day = 5, hour = 12 })
  )
  assert_true(#lines >= 1, "example countdowns produce lines")

  local cfg = dofile(REPO .. "config.lua")
  assert_eq(cfg.showDuration, 8, "config showDuration default 8")
  assert_true(cfg.onlyFirstUnlockOfDay == true, "config onlyFirstUnlockOfDay true")
  assert_eq(cfg.contentFile, "content.json", "config points at content.json")
  assert_true(cfg.countdowns == nil, "countdowns live in content.json not config.lua")
end

print("")
print(string.format("Results: %d passed, %d failed", passed, failed))
if failed > 0 then
  print("Failures:")
  for _, m in ipairs(failures) do
    print("  - " .. m)
  end
  os.exit(1)
end
print("All briefing unit tests passed.")
os.exit(0)
