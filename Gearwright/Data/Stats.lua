-- Gearwright: canonical stat keys and how raw item data maps onto them.
--
-- Weight tables (Data/<CLASS>/Weights.lua) are keyed by these short keys.
-- UNITS ARE UNCONFIRMED: Forever may report hit/crit as % (Classic style,
-- via "Equip:" lines) or as ratings (Mainline style). The first beta capture
-- had no hit/crit gear, so this is still open; weights assume "% points".
local _, ns = ...

local Stats = {}
ns.Stats = Stats

Stats.KEYS = { "agi", "str", "sta", "ap", "hit", "crit", "haste", "expertise", "dps" }

Stats.LABELS = {
  agi = "Agility", str = "Strength", sta = "Stamina", ap = "Attack Power",
  hit = "Hit", crit = "Crit", haste = "Haste", expertise = "Expertise", dps = "Weapon DPS",
}

-- GetItemStats tokens -> our keys. Extend from probe output (tools/probe_to_json.py
-- prints every token it sees).
Stats.TOKEN_TO_KEY = {
  ITEM_MOD_AGILITY_SHORT = "agi",
  ITEM_MOD_STRENGTH_SHORT = "str",
  ITEM_MOD_STAMINA_SHORT = "sta",
  ITEM_MOD_ATTACK_POWER_SHORT = "ap",
  ITEM_MOD_HIT_RATING_SHORT = "hit",
  ITEM_MOD_HIT_MELEE_RATING_SHORT = "hit",
  ITEM_MOD_CRIT_RATING_SHORT = "crit",
  ITEM_MOD_CRIT_MELEE_RATING_SHORT = "crit",
  ITEM_MOD_HASTE_RATING_SHORT = "haste",
  ITEM_MOD_EXPERTISE_RATING_SHORT = "expertise",
  ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps",
}

-- English-only "Equip:" patterns for Classic-style effects. Localize later.
Stats.TOOLTIP_PATTERNS = {
  { pattern = "chance to hit by (%d+)%%", key = "hit" },
  { pattern = "critical strike by (%d+)%%", key = "crit" },
  { pattern = "%+(%d+) Attack Power%.?$", key = "ap" }, -- not "... against Humanoids."
  { pattern = "[Ee]xpertise by (%d+)", key = "expertise" },
  { pattern = "[Hh]aste by (%d+)%%", key = "haste" },
}

function Stats.FromRaw(raw)
  local out = {}
  for token, value in pairs(raw or {}) do
    local key = Stats.TOKEN_TO_KEY[token]
    if key and type(value) == "number" then out[key] = (out[key] or 0) + value end
  end
  return out
end

-- Classic-style clients often report an "Equip:" bonus in GetItemStats too
-- (e.g. "+20 Attack Power" as ITEM_MOD_ATTACK_POWER_SHORT = 20), so a stat
-- already present in `stats` is not added again from the tooltip.
-- Confirmed on the Forever beta: Catacomb Cloak reports ITEM_MOD_ATTACK_POWER_SHORT = 3
-- AND "Equip: +3 Attack Power." Still unverified for hit/crit "Equip:" lines.
function Stats.AddTooltipEffects(stats, lines)
  local fromRaw = {}
  for key in pairs(stats) do fromRaw[key] = true end
  for _, line in ipairs(lines or {}) do
    if line:find("^Equip:") then
      for _, p in ipairs(Stats.TOOLTIP_PATTERNS) do
        local n = not fromRaw[p.key] and tonumber(line:match(p.pattern))
        if n then stats[p.key] = (stats[p.key] or 0) + n end
      end
    end
  end
  return stats
end

-- Normalized stats for an item link, or nil if unreadable.
function Stats.FromLink(link)
  local raw = ns.API.GetItemStats(link)
  if not raw then return nil end
  local stats = Stats.FromRaw(raw)
  return Stats.AddTooltipEffects(stats, ns.API.GetItemTooltipLines(link))
end
