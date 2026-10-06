-- Gearwright: small shared helpers.
local _, ns = ...

local util = {}
ns.util = util

local PREFIX = "|cff4fc3f7Gearwright|r: "

local function fmt(s, ...)
  if select("#", ...) > 0 then return s:format(...) end
  return s
end

function util.print(s, ...)
  print(PREFIX .. fmt(s, ...))
end

function util.debug(s, ...)
  if ns.db and ns.db.debug then
    print(PREFIX .. "|cff999999[debug]|r " .. fmt(s, ...))
  end
end

function util.copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, val in pairs(v) do out[k] = util.copy(val) end
  return out
end

-- Fill missing keys in `t` from `defaults`, recursing into sub-tables.
function util.applyDefaults(t, defaults)
  for k, v in pairs(defaults) do
    if t[k] == nil then
      t[k] = util.copy(v)
    elseif type(v) == "table" and type(t[k]) == "table" then
      util.applyDefaults(t[k], v)
    end
  end
  return t
end

function util.round(n, places)
  local m = 10 ^ (places or 0)
  return math.floor(n * m + 0.5) / m
end

-- Background work -------------------------------------------------------------
-- util.Background(fn, done) runs fn() a slice per frame instead of all at once,
-- so a long job (scoring every crafted item) doesn't freeze the game. Long
-- loops call util.Breathe() as they go; it hands the frame back once the slice
-- is used up, and does nothing outside a background job. done(ok, ...) gets
-- fn's results (or false, error) when it finishes.
local SLICE_MS, SLICE_STEPS = 4, 25
local jobs = {}
local sliceStart, steps = 0, 0

local function now() return debugprofilestop and debugprofilestop() end

function util.Breathe()
  local co, isMain = coroutine.running()
  if not co or isMain then return end -- Lua 5.1 returns nil on the main thread
  steps = steps + 1
  local t = now()
  if (t and t - sliceStart >= SLICE_MS) or (not t and steps >= SLICE_STEPS) then coroutine.yield() end
end

local function step()
  local job = jobs[1]
  if not job then return util.runner:Hide() end
  sliceStart, steps = now() or 0, 0
  local res = { coroutine.resume(job.co) }
  if coroutine.status(job.co) == "dead" then
    table.remove(jobs, 1)
    if job.done then job.done(unpack(res)) end
  end
end

function util.Background(fn, done)
  if not util.runner then
    util.runner = CreateFrame("Frame")
    util.runner:SetScript("OnUpdate", step)
  end
  jobs[#jobs + 1] = { co = coroutine.create(fn), done = done }
  util.runner:Show()
end
