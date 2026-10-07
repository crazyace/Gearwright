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

-- The class's per-level value from Data/ClassStats.lua (Forever's own table),
-- else the class data's {level, value} points. nil when neither knows.
function Weights.ClassStat(classData, char, key)
  local level = char and char.level
  local stats = char and char.class and ns.Data.CLASS_STATS and ns.Data.CLASS_STATS[char.class]
  local series = stats and stats[key]
  if series and level and #series > 0 then
    local v = series[math.max(1, math.min(level, #series))]
    if v and v > 0 then return v end
  end
  return Weights.Interpolate(classData[key], level)
end

local DEFAULT_SPEED = 2.0 -- when the snapshot has no weapon speed

-- Casters (Data/<CLASS>/Weights.lua: model = "caster") score in points of their
-- spec's main power instead of attack power: bonus healing for a healer, spell
-- damage for a damage spec. Ratings are valued like the melee ones, as a share
-- of your output: 1% is worth powerPerPercent (by level) points of power.
-- Melee weapon DPS counts for nothing; a wand's DPS (ranged slot) does.
function Weights.BuildCaster(classData, spec, char, talents)
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
  local effects = Weights.TalentEffects(classData, talents)
  Weights.ApplyTalents(w, effects, "scale")
  local intPerCrit = Weights.ClassStat(classData, char, "intPerSpellCrit")
  if intPerCrit and intPerCrit > 1 then w.int = w.int + w.spellCrit / intPerCrit end
  Weights.ApplyTalents(w, effects, "mult")
  Weights.ApplyTalents(w, effects, "from")
  w.sp = w.healing + w.spellDamage -- "damage and healing done by magical spells"
  for _, school in ipairs(ns.Stats.SCHOOLS) do
    w[school .. "Damage"] = (base.schools and base.schools[school]) and w.spellDamage or 0
  end
  w.powerPerPercent = pct
  w.talents = effects
  return w
end

-- char: { level = n, class = "ROGUE", mainHandDps = n, mainHandSpeed = n, offHandSpeed = n }  (any may be nil)
-- talents: { [name] = { rank = n, max = n } } from Spec.Talents(), or nil.
function Weights.Build(classData, spec, char, talents)
  if classData.weights.model == "caster" then return Weights.BuildCaster(classData, spec, char, talents) end
  local base = classData.weights[spec]
  local pct = Weights.APPerPercent(char)
  local w = {
    ap = 1, str = 1, sta = base.sta or 0,
    mainHandDps = 14, offHandDps = 7, rangedDps = base.rangedDps or 0,
  }
  for _, key in ipairs(Weights.RATINGS) do w[key] = (base[key] or 0) * pct end
  local effects = Weights.TalentEffects(classData, talents)
  Weights.ApplyTalents(w, effects, "scale")
  local agiPerCrit = Weights.ClassStat(classData, char, "agiPerCrit")
  w.agi = 1 + ((agiPerCrit and agiPerCrit > 1) and w.crit / agiPerCrit or 0)
  Weights.ApplyTalents(w, effects, "mult")
  Weights.ApplyTalents(w, effects, "from")
  w.apPerPercent = pct
  w.mainHandSpeed = (char and char.mainHandSpeed) or DEFAULT_SPEED
  w.offHandSpeed = (char and char.offHandSpeed) or w.mainHandSpeed
  w.talents = effects
  return w
end

-- Talents that change what a stat is worth -------------------------------------
--
-- classData.talentEffects (Data/<CLASS>/Weights.lua), by talent name:
--   stat     the weight it changes
--   amount   the effect at max rank, or per rank when perRank = true; the
--            player's rank takes its share
--   kind     "scale": that weight x (1 + amount x share), before Agility and
--                     Intellect take their share of crit (a bigger crit bonus)
--            "mult":  the stat's weight x (1 + amount), after (+15% Intellect)
--            "from":  the stat also gives `amount x weight` of each key in
--                     `into` (Spirit into healing)
--   share    "scale" only: the part of your output it touches (default 1)
--   note     what it does, for the window's header

-- The talents the player has that change a weight, in the order listed:
-- { { name=, rank=, max=, amount=, effect= }, ... }
function Weights.TalentEffects(classData, talents)
  local out = {}
  if not talents or not classData.talentEffects then return out end
  for _, e in ipairs(classData.talentEffects) do
    local t = talents[e.name]
    if t and (t.rank or 0) > 0 then
      local max = math.max(t.max or 1, 1)
      local rank = math.min(t.rank, max)
      local amount = e.perRank and e.amount * rank or e.amount * rank / max
      out[#out + 1] = { name = e.name, rank = rank, max = max, amount = amount, effect = e }
    end
  end
  return out
end

function Weights.ApplyTalents(w, effects, kind)
  for _, t in ipairs(effects) do
    local e = t.effect
    if e.kind == kind then
      if kind == "scale" then
        w[e.stat] = (w[e.stat] or 0) * (1 + t.amount * (e.share or 1))
      elseif kind == "mult" then
        w[e.stat] = (w[e.stat] or 0) * (1 + t.amount)
      elseif kind == "from" then
        for key, k in pairs(e.into) do w[e.stat] = (w[e.stat] or 0) + t.amount * k * (w[key] or 0) end
      end
    end
  end
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
