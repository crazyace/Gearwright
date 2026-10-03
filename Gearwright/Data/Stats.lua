-- Gearwright: canonical stat keys and how raw item data maps onto them.
--
-- Weight tables (Data/<CLASS>/Weights.lua) are keyed by these short keys.
-- Hit, crit, haste and expertise are kept in % points. Forever items carry
-- ratings, but their tooltips show a fixed % ("Improves your chance to hit by
-- 2.0%"); see RATING_PER_PERCENT.
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

-- Rating per 1%, the same at every item level. From 40 Forever leather items on
-- Wowhead (2026-10-03), comparing each item's stored rating with its tooltip:
-- hit 10 -> "1.0%", 20 -> "2.0%", 3 -> "0.3%"; crit 14 -> "1.0%", 21 -> "1.5%";
-- haste and expertise 10 -> "1.0%". Not yet seen in the beta client itself.
Stats.RATING_PER_PERCENT = { hit = 10, crit = 14, haste = 10, expertise = 10 }

-- English-only "Equip:" patterns. Forever writes "by 2.0%", Classic "by 2%".
-- Localize later.
Stats.TOOLTIP_PATTERNS = {
  { pattern = "chance to hit by ([%d%.]+)%%", key = "hit" },
  { pattern = "critical strike by ([%d%.]+)%%", key = "crit" },
  { pattern = "%+(%d+) Attack Power%.?$", key = "ap" }, -- not "... against Humanoids."
  { pattern = "[Ee]xpertise by ([%d%.]+)", key = "expertise" },
  { pattern = "Dodged or Parried by ([%d%.]+)%%", key = "expertise" },
  { pattern = "[Hh]aste by ([%d%.]+)%%", key = "haste" },
  { pattern = "attack speed.- by ([%d%.]+)%%", key = "haste" },
}

function Stats.FromRaw(raw)
  local out = {}
  for token, value in pairs(raw or {}) do
    local key = Stats.TOKEN_TO_KEY[token]
    if key and type(value) == "number" then
      local per = token:find("RATING") and Stats.RATING_PER_PERCENT[key]
      out[key] = (out[key] or 0) + (per and value / per or value)
    end
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
