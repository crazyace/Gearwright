-- Gearwright: what to learn at your class trainer.
-- The spell list (name, rank, level, cost) starts from Data/<Class>/Trainer.lua
-- and grows with every class trainer visit on the account. What each character
-- has learned is read at their own visits: the trainer window lists what you
-- can learn now and later, so a spell at or below your level that it doesn't
-- list (or lists as already known) is learned. Visiting again after training
-- updates it; until a character's first visit, only the level-up reminder for
-- brand-new spells works.
local _, ns = ...

local ClassTrainer = {}
ns.ClassTrainer = ClassTrainer

local function key(name, rank) return name .. "|" .. (rank or "") end

local function classData() return ns.Spec.ClassData() end

-- Every known spell for your class: { [key] = { name, rank, level, cost } }
function ClassTrainer.Spells()
  local data = classData()
  local out = {}
  for _, s in ipairs(data and data.trainer and data.trainer.spells or {}) do
    out[key(s.name, s.rank)] = { name = s.name, rank = s.rank, level = s.level, cost = s.cost }
  end
  local _, class = UnitClass("player")
  for k, s in pairs(ns.db and ns.db.classSpells and ns.db.classSpells[class] or {}) do
    local have = out[k]
    if have then
      if s.cost and not have.cost then have.cost = s.cost end
    else
      out[k] = s
    end
  end
  return out
end

-- This character's last visit: { level, known = { [key] = true }, open = { [key] = true } }
local function visit()
  if not ns.db then return nil end
  ns.db.trained = ns.db.trained or {}
  return ns.db.trained[ns.Professions.CharKey()]
end

-- Class trainers for your class, nearest first: { { name, city, mapID, x, y } }
function ClassTrainer.Trainers()
  local data = classData()
  local list, seen = {}, {}
  local _, class = UnitClass("player")
  for _, t in pairs(ns.db and ns.db.classTrainers and ns.db.classTrainers[class] or {}) do
    list[#list + 1] = t
    if t.npcID then seen[t.npcID] = true end
  end
  for _, t in ipairs(data and data.trainer and data.trainer.trainers or {}) do
    if not (t.npcID and seen[t.npcID]) then list[#list + 1] = t end
  end
  local here = ns.Trainers.Here()
  table.sort(list, function(a, b)
    local da, db = ns.Trainers.Distance(a, here), ns.Trainers.Distance(b, here)
    if da ~= db then return da < db end
    return tostring(a.name) < tostring(b.name)
  end)
  return list
end

-- Has this character learned spell `s`? true / false / nil (no visit yet, or
-- it unlocked after the last visit).
function ClassTrainer.Learned(s)
  local v = visit()
  if not v then return nil end
  local k = key(s.name, s.rank)
  if v.known[k] then return true end
  if v.open[k] then return false end
  if s.level <= v.level then return true end -- not listed then, so learned
  return nil
end

-- Spells you can train at your level and haven't, by level:
-- list sorted by level, plus whether a visit has ever been recorded.
function ClassTrainer.ToTrain(level)
  level = level or ns.API.clean(UnitLevel("player")) or 1
  local out = {}
  local v = visit()
  for _, s in pairs(ClassTrainer.Spells()) do
    if s.level <= level then
      local learned = ClassTrainer.Learned(s)
      -- Without a visit, only spells newer than... nothing is known: report
      -- just this level's spells (see NewAt) rather than guess.
      if learned == false or (learned == nil and v) then out[#out + 1] = s end
    end
  end
  table.sort(out, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    return a.name < b.name
  end)
  return out, v ~= nil
end

-- Spells that unlock exactly at `level`.
function ClassTrainer.NewAt(level)
  local out = {}
  for _, s in pairs(ClassTrainer.Spells()) do
    if s.level == level then out[#out + 1] = s end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- "Backstab 3" / "Distract"
function ClassTrainer.Label(s)
  local r = s.rank and s.rank:match("^Rank (%d+)$")
  return s.name .. (r and (" " .. r) or "")
end

-- Total cost in copper of `list`, or nil when any cost is unknown.
function ClassTrainer.Cost(list)
  local total = 0
  for _, s in ipairs(list) do
    if not s.cost then return nil end
    total = total + s.cost
  end
  return total
end

-- Trainer window open: if it's a trainer for your class, save its spell list
-- (levels, costs), where it stands, and what this character has learned.
function ClassTrainer.Record()
  if not (GetNumTrainerServices and GetTrainerServiceInfo) then return end
  local spells = ClassTrainer.Spells()
  local rows, matches = {}, 0
  for i = 1, GetNumTrainerServices() or 0 do
    local ok, name, status, _, level, rank = pcall(GetTrainerServiceInfo, i)
    name, status, level, rank = ns.API.clean(name), ns.API.clean(status), ns.API.clean(level), ns.API.clean(rank)
    if ok and type(name) == "string" then
      if GetTrainerServiceLevelReq then
        local okL, l = pcall(GetTrainerServiceLevelReq, i)
        if okL and type(ns.API.clean(l)) == "number" and ns.API.clean(l) > 0 then level = ns.API.clean(l) end
      end
      local cost
      if GetTrainerServiceCost then
        local okC, c = pcall(GetTrainerServiceCost, i)
        cost = okC and ns.API.clean(c) or nil
      end
      local k = key(name, type(rank) == "string" and rank or "")
      if spells[k] then matches = matches + 1 end
      rows[#rows + 1] = { k = k, name = name, rank = type(rank) == "string" and rank or "", status = status,
        level = type(level) == "number" and level or 0, cost = type(cost) == "number" and cost > 0 and cost or nil }
    end
  end
  if matches < 3 then return end -- not your class trainer
  local _, class = UnitClass("player")
  ns.db.classSpells = ns.db.classSpells or {}
  ns.db.classSpells[class] = ns.db.classSpells[class] or {}
  local myLevel = ns.API.clean(UnitLevel("player")) or 1
  local v = { level = myLevel, known = {}, open = {} }
  for _, r in ipairs(rows) do
    if r.level > 0 then
      local saved = ns.db.classSpells[class][r.k] or {}
      ns.db.classSpells[class][r.k] = { name = r.name, rank = r.rank, level = r.level, cost = r.cost or saved.cost }
    end
    if r.status == "used" then v.known[r.k] = true else v.open[r.k] = true end
  end
  ns.db.trained = ns.db.trained or {}
  ns.db.trained[ns.Professions.CharKey()] = v
  -- Where this trainer stands.
  local guid = UnitGUID and ns.API.clean(UnitGUID("npc"))
  local npcID = type(guid) == "string" and tonumber(guid:match("^%a+%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)"))
  local mapID, x, y = ns.API.PlayerMapPosition()
  if npcID then
    ns.db.classTrainers = ns.db.classTrainers or {}
    ns.db.classTrainers[class] = ns.db.classTrainers[class] or {}
    ns.db.classTrainers[class][npcID] = { npcID = npcID, name = ns.API.clean(UnitName("npc")), mapID = mapID,
      x = x, y = y, city = ns.API.clean(GetRealZoneText and GetRealZoneText()) }
  end
  return true
end

for _, event in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE" }) do
  ns:On(event, function()
    if C_Timer then C_Timer.After(0.6, ClassTrainer.Record) else ClassTrainer.Record() end
  end)
end
