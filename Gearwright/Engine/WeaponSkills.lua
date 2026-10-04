-- Gearwright: weapon skill levels.
-- Forever keeps Classic's weapon skills: each weapon type has a skill up to
-- 5 x your level, a newly trained one starts at 1 (Swords 1/95 at level 19 on
-- the beta), and a low skill means many misses until it's levelled by fighting
-- with that weapon. No API lists the levels (GetSkillLineInfo is gone), so:
--   * any tooltip that shows "Daggers:  95/95" (the character sheet's Main Hand
--     and Off Hand lines) is read and saved;
--   * a skill seen going from unknown to known was just trained: it's at 1.
local _, ns = ...

local WeaponSkills = {}
ns.WeaponSkills = WeaponSkills

-- Skill names as tooltips write them -> weapon subclass.
local SUBCLASS = {
  ["Daggers"] = 15, ["Swords"] = 7, ["One-Handed Swords"] = 7, ["Two-Handed Swords"] = 8,
  ["Maces"] = 4, ["One-Handed Maces"] = 4, ["Two-Handed Maces"] = 5,
  ["Axes"] = 0, ["One-Handed Axes"] = 0, ["Two-Handed Axes"] = 1,
  ["Fist Weapons"] = 13, ["Polearms"] = 6, ["Staves"] = 10, ["Bows"] = 2, ["Guns"] = 3,
  ["Crossbows"] = 18, ["Thrown"] = 16, ["Wands"] = 19,
}
WeaponSkills.SUBCLASS = SUBCLASS

-- Below this many points under the maximum, warn (Classic: past 10 points the
-- miss chance climbs steeply).
WeaponSkills.WARN_BELOW = 10

local function store()
  if not ns.db then return nil end
  ns.db.weaponSkills = ns.db.weaponSkills or {}
  local key = ns.Professions.CharKey()
  ns.db.weaponSkills[key] = ns.db.weaponSkills[key] or { levels = {} }
  return ns.db.weaponSkills[key]
end

local function level() return ns.API.clean(UnitLevel("player")) or 1 end

function WeaponSkills.Record(sub, current, max)
  local s = store()
  if not s then return end
  s.levels[sub] = { current = current, max = max, level = level() }
end

-- Read "Daggers:  95/95" style lines; returns how many were saved.
function WeaponSkills.ReadLines(lines)
  local n = 0
  for _, line in ipairs(lines or {}) do
    if type(line) == "string" then
      local name, cur, max = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :match("^%s*(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
      local sub = name and SUBCLASS[name]
      if sub then
        WeaponSkills.Record(sub, tonumber(cur), tonumber(max))
        n = n + 1
      end
    end
  end
  return n
end

-- Called with the set of trained weapon subclasses (Advisor.KnownWeaponSkills):
-- a subclass that wasn't known last time was just trained, so it's at 1.
function WeaponSkills.Update(known)
  local s = store()
  if not (s and known) then return end
  if s.known then
    for sub in pairs(known) do
      if not s.known[sub] and not s.levels[sub] then
        WeaponSkills.Record(sub, 1, 5 * level())
      end
    end
  end
  s.known = {}
  for sub in pairs(known) do s.known[sub] = true end
end

-- What we know of a subclass's skill: current, max (5 x your level now), and
-- whether `current` was read at an earlier level (it may have gone up since).
function WeaponSkills.Get(sub)
  local s = store()
  local rec = s and s.levels[sub]
  if not rec then return nil end
  return rec.current, 5 * level(), rec.level ~= level()
end

-- "Swords 1/95" when that skill is too low to fight well with, else nil.
function WeaponSkills.Warning(sub, name)
  local cur, max, old = WeaponSkills.Get(sub)
  if not cur or cur + WeaponSkills.WARN_BELOW >= max then return nil end
  return ("%s %d/%d%s"):format(name, cur, max, old and " when last seen" or "")
end

-- Read every tooltip the game shows (the character sheet's weapon lines).
ns:On("PLAYER_LOGIN", function()
  local tip = rawget(_G, "GameTooltip")
  if not (tip and hooksecurefunc and tip.NumLines) then return end
  hooksecurefunc(tip, "Show", function(self)
    local lines = {}
    for i = 1, math.min(self:NumLines() or 0, 12) do
      local fs = _G["GameTooltipTextLeft" .. i]
      lines[i] = fs and fs.GetText and ns.API.clean(fs:GetText()) or ""
    end
    WeaponSkills.ReadLines(lines)
  end)
end)
