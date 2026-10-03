-- Gearwright: turn item stats into a single score with spec weights.
-- Pure functions only (no WoW API) so they can be unit-tested outside the game.
-- `slot` matters for weapons: off-hand DPS is worth half of main-hand DPS.
local _, ns = ...

local Scoring = {}
ns.Scoring = Scoring

function Scoring.ScoreStats(stats, weights, slot)
  local total = 0
  for key, value in pairs(stats or {}) do
    local w = ns.Weights.For(weights, key, slot)
    if w then total = total + value * w end
  end
  return total
end

-- Per-stat contribution, largest first. Used to explain WHY an item scores well.
function Scoring.Breakdown(stats, weights, slot)
  local parts = {}
  for key, value in pairs(stats or {}) do
    local w = ns.Weights.For(weights, key, slot)
    if w and value ~= 0 then parts[#parts + 1] = { key = key, value = value, score = value * w } end
  end
  table.sort(parts, function(a, b) return math.abs(a.score) > math.abs(b.score) end)
  return parts
end

function Scoring.ScoreLink(link, weights, slot)
  local stats = ns.Stats.FromLink(link)
  if not stats then return nil end
  return Scoring.ScoreStats(stats, weights, slot), stats
end
