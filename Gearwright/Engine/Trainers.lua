-- Gearwright: where to train a weapon skill.
-- Starts from Data/WeaponMasters.lua (Classic positions, a few checked on Forever)
-- and learns from the game: opening any trainer that teaches a weapon skill
-- saves its real position and skills (account-wide), which then win.
local _, ns = ...

local Trainers = {}
ns.Trainers = Trainers

-- Every weapon skill name we know of, so a trainer's services can be matched.
local SKILL_NAMES = {}
for _, n in ipairs({ "Daggers", "One-Handed Swords", "Two-Handed Swords", "One-Handed Maces",
  "Two-Handed Maces", "One-Handed Axes", "Two-Handed Axes", "Fist Weapons", "Polearms", "Staves",
  "Bows", "Guns", "Crossbows", "Thrown", "Wands" }) do SKILL_NAMES[n] = true end

-- Weapon masters for your faction, learned ones first: { { name, mapID, x, y, city, skills, seen } }
function Trainers.All()
  local faction = ns.API.PlayerFaction()
  local out, seen, seed = {}, {}, {}
  for _, t in ipairs(ns.Data.WEAPON_MASTERS or {}) do seed[t.npcID] = t end
  for npcID, t in pairs(ns.db and ns.db.trainers or {}) do
    -- A visit saves the real position; keep the seed's directions with it.
    -- The trainer's window only lists what your class can learn, so keep the
    -- seed's other skills too.
    local s = seed[npcID]
    if s then
      if t.detail == nil then t.detail = s.detail end
      local have = {}
      for _, k in ipairs(t.skills) do have[k] = true end
      for _, k in ipairs(s.skills) do
        if not have[k] then t.skills[#t.skills + 1] = k end
      end
    end
    if not faction or not t.faction or t.faction == faction then
      out[#out + 1] = t
      seen[npcID] = true
    end
  end
  table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
  for _, t in ipairs(ns.Data.WEAPON_MASTERS or {}) do
    if not seen[t.npcID] and (not faction or t.faction == faction) then out[#out + 1] = t end
  end
  return out
end

-- How far a trainer is: 0 in the zone you're in, 1 on your continent, 2 elsewhere.
function Trainers.Distance(t, here)
  if not here or not here.mapID then return 1 end
  if t.mapID == here.mapID then return 0 end
  local cont = t.continent or ns.API.ContinentOf(t.mapID)
  if cont and here.continent and cont == here.continent then return 1 end
  return 2
end

-- Where you are: { mapID, continent } or nil.
function Trainers.Here()
  local mapID = ns.API.PlayerMapPosition()
  if not mapID then return nil end
  return { mapID = mapID, continent = ns.API.ContinentOf(mapID) }
end

-- Trainers who teach `skill`, nearest first; ties keep the checked-in-game
-- ones first, then Data/WeaponMasters.lua's order.
function Trainers.For(skill, here)
  if here == nil then here = Trainers.Here() end
  local out = {}
  for i, t in ipairs(Trainers.All()) do
    for _, s in ipairs(t.skills or {}) do
      if s == skill then out[#out + 1] = { t = t, d = Trainers.Distance(t, here), i = i }; break end
    end
  end
  table.sort(out, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    return a.i < b.i
  end)
  for k, e in ipairs(out) do out[k] = e.t end
  return out
end

local function pin(t)
  ns.MapPins.Add({
    mapID = t.mapID, x = t.x, y = t.y, title = t.name .. " (weapon master)",
    text = (t.detail and (t.detail:gsub("^%l", string.upper) .. ". ") or "") .. "Teaches " .. table.concat(t.skills, ", "),
    note = not (t.seen or t.checked) and "Classic position, not checked on Forever yet" or nil,
  })
end

-- "Woo Ping, Stormwind (inside the Just Maces shop)" for the nearest trainer
-- of `skill`, or nil.
function Trainers.Where(skill)
  local t = Trainers.For(skill)[1]
  if not t then return nil end
  return t.name .. (t.city and (", " .. t.city) or "") .. (t.detail and (" (" .. t.detail .. ")") or "")
end

-- Pin the trainers of `skill` on the world map and open it on the nearest.
function Trainers.Show(skill)
  local list = Trainers.For(skill)
  if #list == 0 then
    ns.util.print("no weapon master known for %s yet; open one and Gearwright will remember it", skill)
    return
  end
  for _, t in ipairs(list) do pin(t) end
  local t = list[1]
  ns.util.print("train %s with %s%s%s%s", skill, t.name, t.city and (" in " .. t.city) or "",
    t.detail and (", " .. t.detail) or "",
    (t.seen or t.checked) and "" or " (Classic position, not checked on Forever yet)")
  ns.MapPins.Open(t.mapID)
end

-- Several skills at once: the nearest trainer for each, grouped by trainer,
-- nearest trainer first: { { trainer, skills = { ... }, distance }, ... }.
-- Skills nobody is known to teach are returned second.
function Trainers.Plan(skills)
  local here = Trainers.Here()
  local byTrainer, order, unknown = {}, {}, {}
  for _, skill in ipairs(skills) do
    local t = Trainers.For(skill, here)[1]
    if not t then
      unknown[#unknown + 1] = skill
    else
      local g = byTrainer[t]
      if not g then
        g = { trainer = t, skills = {}, distance = Trainers.Distance(t, here) }
        byTrainer[t] = g
        order[#order + 1] = g
      end
      g.skills[#g.skills + 1] = skill
    end
  end
  table.sort(order, function(a, b)
    if a.distance ~= b.distance then return a.distance < b.distance end
    return #a.skills > #b.skills
  end)
  return order, unknown
end

-- Pin a plan's trainers and open the map on the nearest.
function Trainers.ShowPlan(plan)
  for _, g in ipairs(plan) do pin(g.trainer) end
  if plan[1] then ns.MapPins.Open(plan[1].trainer.mapID) end
end

-- Opening a trainer: if it teaches weapon skills, remember where it is.
function Trainers.Record()
  if not (GetNumTrainerServices and GetTrainerServiceInfo) then return end
  local skills = {}
  for i = 1, GetNumTrainerServices() or 0 do
    local ok, name = pcall(GetTrainerServiceInfo, i)
    name = ok and ns.API.clean(name)
    if name and SKILL_NAMES[name] then skills[#skills + 1] = name end
  end
  if #skills == 0 then return end
  local guid = UnitGUID and ns.API.clean(UnitGUID("npc"))
  local npcID = type(guid) == "string" and tonumber(guid:match("^%a+%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)"))
  local mapID, x, y = ns.API.PlayerMapPosition()
  if not (npcID and mapID) then return end
  ns.db.trainers = ns.db.trainers or {}
  ns.db.trainers[npcID] = {
    npcID = npcID, name = ns.API.clean(UnitName("npc")), faction = ns.API.PlayerFaction(),
    mapID = mapID, x = x, y = y, city = ns.API.clean(GetRealZoneText and GetRealZoneText()),
    skills = skills, seen = date and date("%Y-%m-%d") or true,
  }
end

ns:On("TRAINER_SHOW", function()
  if C_Timer then C_Timer.After(0.5, Trainers.Record) else Trainers.Record() end
end)
