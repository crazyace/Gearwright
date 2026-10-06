-- Gearwright: which weapon buff, elixirs and potions to use, from
-- Data/Consumables.lua. Pure functions only (no WoW API): Advisor gathers the
-- character and calls Consumables.Report.
local _, ns = ...

local Consumables = {}
ns.Consumables = Consumables

-- Weapon subclass -> what a stone fits. Weightstones are for blunt weapons;
-- fist weapons are counted blunt (unconfirmed). Ranged weapons and wands take
-- no weapon buff.
local KIND = {
  [0] = "sharp", [1] = "sharp", [6] = "sharp", [7] = "sharp", [8] = "sharp", [15] = "sharp",
  [4] = "blunt", [5] = "blunt", [10] = "blunt", [13] = "blunt",
}
function Consumables.WeaponKind(subclassID) return KIND[subclassID] end

local function fits(item, kind)
  return kind and (item.what == "any" or item.what == kind)
end

-- Poison damage per second on a weapon of `speed`. A DoT stops adding once it
-- has all its stacks: `capLeft` is how much of that is still free (the other
-- hand may have used some).
function Consumables.PoisonDps(p, speed, capLeft)
  local dps = p.chance * p.damage / (speed or 2.0)
  if p.duration then
    local cap = capLeft or (p.stacks or 1) * p.damage / p.duration
    dps = math.min(dps, cap)
  end
  return dps
end

-- Earliest item above `level` (within `lookahead` levels) that beats `bestScore`.
local function nextUp(candidates, level, lookahead, bestScore)
  local nxt
  for _, c in ipairs(candidates) do
    if c.item.level > level and c.item.level <= level + lookahead and c.score > bestScore
        and (not nxt or c.item.level < nxt.item.level or (c.item.level == nxt.item.level and c.score > nxt.score)) then
      nxt = c
    end
  end
  return nxt
end

local function bestNow(candidates, level)
  local best
  for _, c in ipairs(candidates) do
    if c.item.level <= level and c.score > 0 and (not best or c.score > best.score) then best = c end
  end
  return best
end

-- One hand's buff choices, scored for `slot`.
local function weaponCandidates(data, input, slot, hand, deadlyUsed)
  local out = {}
  for _, item in ipairs(data.weapon or {}) do
    if fits(item, hand.kind) then
      out[#out + 1] = { item = item, score = ns.Scoring.ScoreStats(item.stats, input.weights, slot) }
    end
  end
  local poisons = data.poisons
  local perDps = input.weights.mainHandDps or 0 -- poison damage isn't halved in the off hand
  if poisons and hand.kind and input.classToken == poisons.class and perDps > 0 then
    for _, p in ipairs(poisons) do
      local capLeft
      if p.duration then
        capLeft = math.max(0, (p.stacks or 1) * p.damage / p.duration - (deadlyUsed[p.id] or 0))
      end
      local dps = Consumables.PoisonDps(p, hand.speed, capLeft)
      out[#out + 1] = { item = p, score = dps * perDps, dps = dps, poison = true }
    end
  end
  return out
end

-- input = {
--   level, lookahead, weights, classToken, usesMana,
--   hands = { [16] = { kind = "sharp"|"blunt"|nil, speed = n }, [17] = {...} },
-- }
-- Returns {
--   weapon  = { { slot, best = {item, score, ...}, next = {...} or nil }, ... }  hands with a melee weapon
--   elixirs = { { group, best, next }, ... }  best first
--   potions = { { restores, best, next }, ... }  health, then mana for mana users
-- }
function Consumables.Report(data, input)
  local level, ahead = input.level or 1, input.lookahead or 0
  local report = { weapon = {}, elixirs = {}, potions = {} }

  local deadlyUsed = {}
  for _, slot in ipairs({ 16, 17 }) do
    local hand = input.hands and input.hands[slot]
    if hand and hand.kind then
      local cands = weaponCandidates(data, input, slot, hand, deadlyUsed)
      local best = bestNow(cands, level)
      if best and best.item.duration then deadlyUsed[best.item.id] = (deadlyUsed[best.item.id] or 0) + best.dps end
      local nxt = nextUp(cands, level, ahead, best and best.score or 0)
      if best or nxt then report.weapon[#report.weapon + 1] = { slot = slot, best = best, next = nxt } end
    end
  end

  local groups, order = {}, {}
  for _, item in ipairs(data.elixirs or {}) do
    local score = ns.Scoring.ScoreStats(item.stats, input.weights)
    if not groups[item.group] then groups[item.group] = {}; order[#order + 1] = item.group end
    local g = groups[item.group]
    g[#g + 1] = { item = item, score = score }
  end
  for _, group in ipairs(order) do
    local best = bestNow(groups[group], level)
    local nxt = nextUp(groups[group], level, ahead, best and best.score or 0)
    if best or nxt then report.elixirs[#report.elixirs + 1] = { group = group, best = best, next = nxt } end
  end
  -- What you can use now first, best first; then what's coming.
  table.sort(report.elixirs, function(a, b)
    if (a.best ~= nil) ~= (b.best ~= nil) then return a.best ~= nil end
    local sa, sb = (a.best or a.next).score, (b.best or b.next).score
    if sa ~= sb then return sa > sb end
    return a.group < b.group
  end)

  for _, restores in ipairs({ "health", "mana" }) do
    if restores == "health" or input.usesMana then
      local cands = {}
      for _, item in ipairs(data.potions or {}) do
        if item.restores == restores then cands[#cands + 1] = { item = item, score = item.amount } end
      end
      local best = bestNow(cands, level)
      local nxt = nextUp(cands, level, ahead, best and best.score or 0)
      if best or nxt then report.potions[#report.potions + 1] = { restores = restores, best = best, next = nxt } end
    end
  end
  return report
end
