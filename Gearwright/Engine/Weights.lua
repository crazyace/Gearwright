-- Gearwright: build a spec's full weight table for the character as they are now.
-- Pure functions only (no WoW API); the caller passes in a character snapshot.
local _, ns = ...

local Weights = {}
ns.Weights = Weights

Weights.RATINGS = { "crit", "hit", "haste", "expertise" }

-- Melee DPS = weapon DPS + AP / 14, so 1 AP adds 1/14 DPS and 1% of your
-- damage is worth 0.14 x DPS in attack power.
function Weights.APPerPercent(char)
  local dps = char and char.mainHandDps
  if not dps or dps <= 0 then
    dps = math.max((char and char.level) or 1, 1) -- rough: about level-19 DPS at level 19
  end
  return 0.14 * dps
end

-- points: { {level, value}, ... } sorted by level; linear between them,
-- extended along the nearest segment outside them.
function Weights.Interpolate(points, level)
  if not points or #points == 0 or not level then return nil end
  if #points == 1 then return points[1][2] end
  local a, b = points[1], points[2]
  for i = 2, #points do
    a, b = points[i - 1], points[i]
    if level <= b[1] then break end
  end
  return a[2] + (b[2] - a[2]) * (level - a[1]) / (b[1] - a[1])
end

local DEFAULT_SPEED = 2.0 -- when the snapshot has no weapon speed

-- Casters (Data/<CLASS>/Weights.lua: model = "caster") score in points of their
-- spec's main power instead of attack power: bonus healing for a healer, spell
-- damage for a damage spec. Ratings are valued like the melee ones, as a share
-- of your output: 1% is worth powerPerPercent (by level) points of power.
-- Melee weapon DPS counts for nothing; a wand's DPS (ranged slot) does.
function Weights.BuildCaster(classData, spec, char)
  local base = classData.weights[spec]
  local level = char and char.level
  local pct = Weights.Interpolate(classData.powerPerPercent, level) or 1
  local w = {
    sta = base.sta or 0, int = base.int or 0, spi = base.spi or 0, mp5 = base.mp5 or 0,
    healing = base.healing or 0, spellDamage = base.spellDamage or 0,
    mainHandDps = 0, offHandDps = 0, rangedDps = base.wandDps or 0,
    spellHit = (base.spellHit or 0) * pct, spellCrit = (base.spellCrit or 0) * pct,
    haste = (base.haste or 0) * pct,
  }
  w.sp = w.healing + w.spellDamage -- "damage and healing done by magical spells"
  for _, school in ipairs(ns.Stats.SCHOOLS) do
    w[school .. "Damage"] = (base.schools and base.schools[school]) and w.spellDamage or 0
  end
  local intPerCrit = Weights.Interpolate(classData.intPerSpellCrit, level)
  if intPerCrit and intPerCrit > 1 then w.int = w.int + w.spellCrit / intPerCrit end
  w.powerPerPercent = pct
  return w
end

-- char: { level = n, mainHandDps = n, mainHandSpeed = n, offHandSpeed = n }  (any may be nil)
function Weights.Build(classData, spec, char)
  if classData.weights.model == "caster" then return Weights.BuildCaster(classData, spec, char) end
  local base = classData.weights[spec]
  local pct = Weights.APPerPercent(char)
  local w = {
    ap = 1, str = 1, sta = base.sta or 0,
    mainHandDps = 14, offHandDps = 7, rangedDps = base.rangedDps or 0,
  }
  for _, key in ipairs(Weights.RATINGS) do w[key] = (base[key] or 0) * pct end
  local agiPerCrit = Weights.Interpolate(classData.agiPerCrit, char and char.level)
  w.agi = 1 + ((agiPerCrit and agiPerCrit > 1) and w.crit / agiPerCrit or 0)
  w.apPerPercent = pct
  w.mainHandSpeed = (char and char.mainHandSpeed) or DEFAULT_SPEED
  w.offHandSpeed = (char and char.offHandSpeed) or w.mainHandSpeed
  return w
end

local function dpsWeight(weights, slot)
  if slot == 17 then return weights.offHandDps end
  if slot == 18 then return weights.rangedDps end
  return weights.mainHandDps
end

-- Weight for one stat in one slot: weapon DPS depends on the hand.
-- weaponDamage (flat damage per swing, from enchants) is DPS divided by speed.
function Weights.For(weights, key, slot)
  if key == "dps" then return dpsWeight(weights, slot) end
  if key == "weaponDamage" then
    local speed = (slot == 17 and weights.offHandSpeed) or weights.mainHandSpeed or DEFAULT_SPEED
    local w = dpsWeight(weights, slot)
    return w and w / speed
  end
  return weights[key]
end
