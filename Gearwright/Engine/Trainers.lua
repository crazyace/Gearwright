-- Gearwright: where to train a weapon skill.
-- Starts from Data/WeaponMasters.lua (Classic positions, unchecked on Forever)
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
  local out, seen = {}, {}
  for npcID, t in pairs(ns.db and ns.db.trainers or {}) do
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

-- Trainers who teach `skill`, best first (positions checked in game first).
function Trainers.For(skill)
  local out = {}
  for _, t in ipairs(Trainers.All()) do
    for _, s in ipairs(t.skills or {}) do
      if s == skill then out[#out + 1] = t; break end
    end
  end
  return out
end

-- "Woo Ping, Stormwind" for the first trainer of `skill`, or nil.
function Trainers.Where(skill)
  local t = Trainers.For(skill)[1]
  if not t then return nil end
  return t.name .. (t.city and (", " .. t.city) or "")
end

-- Pin the trainers of `skill` on the world map and open it on the first one.
function Trainers.Show(skill)
  local list = Trainers.For(skill)
  if #list == 0 then
    ns.util.print("no weapon master known for %s yet; open one and Gearwright will remember it", skill)
    return
  end
  for _, t in ipairs(list) do
    ns.MapPins.Add({
      mapID = t.mapID, x = t.x, y = t.y, title = t.name .. " (weapon master)",
      text = "Teaches " .. table.concat(t.skills, ", "),
      note = not t.seen and "Classic position, not checked on Forever yet" or nil,
    })
  end
  local t = list[1]
  ns.util.print("train %s with %s%s%s", skill, t.name, t.city and (" in " .. t.city) or "",
    t.seen and "" or " (Classic position, not checked on Forever yet)")
  ns.MapPins.Open(t.mapID)
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
