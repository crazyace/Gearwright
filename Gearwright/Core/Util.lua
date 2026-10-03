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
