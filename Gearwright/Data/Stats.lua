-- Gearwright: canonical stat keys and how raw item data maps onto them.
--
-- Weight tables (Data/<CLASS>/Weights.lua) are keyed by these short keys.
-- Hit, crit, haste and expertise are kept in % points. Forever items carry
-- ratings, but their tooltips show a fixed % ("Improves your chance to hit by
-- 2.0%"); see RATING_PER_PERCENT.
local _, ns = ...

local Stats = {}
ns.Stats = Stats

Stats.KEYS = { "agi", "str", "sta", "ap", "hit", "crit", "haste", "expertise", "dps",
  "int", "spi", "mp5", "sp", "spellDamage", "healing", "spellHit", "spellCrit" }

-- Spell damage for one school ("Increases damage done by Shadow spells ...").
Stats.SCHOOLS = { "holy", "shadow", "arcane", "fire", "frost", "nature" }

Stats.LABELS = {
  agi = "Agility", str = "Strength", sta = "Stamina", ap = "Attack Power",
  hit = "Hit", crit = "Crit", haste = "Haste", expertise = "Expertise", dps = "Weapon DPS",
  int = "Intellect", spi = "Spirit", armor = "Armor", defense = "Defense",
  dodge = "Dodge", block = "Block", weaponDamage = "Weapon Damage",
  mp5 = "Mana per 5 sec", sp = "Spell Power", spellDamage = "Spell Damage", healing = "Healing",
  spellHit = "Spell Hit", spellCrit = "Spell Crit",
  holyDamage = "Holy Damage", shadowDamage = "Shadow Damage", arcaneDamage = "Arcane Damage",
  fireDamage = "Fire Damage", frostDamage = "Frost Damage", natureDamage = "Nature Damage",
}

-- Names used on the "Enchanted: Stamina +2 and Armor +16" tooltip line.
Stats.ENCHANT_NAMES = {
  Agility = "agi", Strength = "str", Stamina = "sta", Intellect = "int", Spirit = "spi",
  Armor = "armor", Defense = "defense", ["Attack Power"] = "ap",
  ["Weapon Damage"] = "weaponDamage", Damage = "weaponDamage",
}

-- GetItemStats tokens -> our keys. Extend from probe output (tools/probe_to_json.py
-- prints every token it sees).
--
-- Caster stats, from the 2026-10-03 auction house scans (5,295 gear items), where
-- every token below matches its item's "Equip:" line:
--   SPELL_POWER                       "damage and healing done by magical spells ... by up to N" (605 items)
--   SPELL_HEALING_DONE + _DAMAGE_DONE "healing done by up to N and damage done by up to M" (368),
--                                     or HEALING_DONE alone, "healing done by ... up to N" (23)
--   <SCHOOL>_DAMAGE_DONE              "damage done by Shadow spells and effects by up to N"
--   MANA_REGENERATION                 "Restores N Mana per 5 sec." (15)
-- Spell hit and crit weren't on any scanned item: the SPELL_*_RATING tokens are
-- Classic's names, assumed to use the melee rating per 1%.
Stats.TOKEN_TO_KEY = {
  ITEM_MOD_AGILITY_SHORT = "agi",
  ITEM_MOD_STRENGTH_SHORT = "str",
  ITEM_MOD_STAMINA_SHORT = "sta",
  ITEM_MOD_INTELLECT_SHORT = "int",
  ITEM_MOD_SPIRIT_SHORT = "spi",
  ITEM_MOD_MANA_REGENERATION_SHORT = "mp5",
  ITEM_MOD_SPELL_POWER_SHORT = "sp",
  ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "spellDamage",
  ITEM_MOD_SPELL_HEALING_DONE_SHORT = "healing",
  ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = "holyDamage",
  ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = "shadowDamage",
  ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT = "arcaneDamage",
  ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = "fireDamage",
  ITEM_MOD_FROST_DAMAGE_DONE_SHORT = "frostDamage",
  ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = "natureDamage",
  ITEM_MOD_SPELL_HIT_RATING_SHORT = "spellHit",
  ITEM_MOD_SPELL_CRIT_RATING_SHORT = "spellCrit",
  ITEM_MOD_ATTACK_POWER_SHORT = "ap",
  ITEM_MOD_HIT_RATING_SHORT = "hit",
  ITEM_MOD_HIT_MELEE_RATING_SHORT = "hit",
  ITEM_MOD_CRIT_RATING_SHORT = "crit",
  ITEM_MOD_CRIT_MELEE_RATING_SHORT = "crit",
  ITEM_MOD_HASTE_RATING_SHORT = "haste",
  ITEM_MOD_EXPERTISE_RATING_SHORT = "expertise",
  ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps",
}

-- Rating per 1%, the same at every item level. Found on 40 Forever items on
-- Wowhead, then confirmed in the beta client (/gwp items, 2026-10-03): hit 3 ->
-- "0.3%", 20 -> "2.0%"; crit 14 -> "1.0%"; haste and expertise 10 -> "1.0%".
Stats.RATING_PER_PERCENT = { hit = 10, crit = 14, haste = 10, expertise = 10, spellHit = 10, spellCrit = 14 }

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
  -- Classic's wording; not seen on a Forever item yet.
  { pattern = "chance to hit with spells by ([%d%.]+)%%", key = "spellHit" },
  { pattern = "critical strike with spells by ([%d%.]+)%%", key = "spellCrit" },
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
-- AND "Equip: +3 Attack Power." Hit and crit too: across the 5,295 gear items of
-- the 2026-10-03 auction house scan, every one is counted once and matches its tooltip.
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

-- The enchant on an item, from its tooltip. GetItemStats leaves enchants out.
-- Returns stats, text  (stats is {} for an enchant we can't read, e.g. a proc);
-- nil when the item has no "Enchanted:" line.
function Stats.FromEnchantLine(lines)
  for _, line in ipairs(lines or {}) do
    local text = line:match("^Enchanted: (.+)$")
    if text then
      local stats = {}
      for part in (text .. " and "):gmatch("(.-) and ") do
        local name, n = part:match("^(.-) %+(%d+)$")
        if not name then n, name = part:match("^%+(%d+) (.-)$") end
        local key = name and Stats.ENCHANT_NAMES[name]
        if key then stats[key] = (stats[key] or 0) + tonumber(n) end
      end
      return stats, text
    end
  end
end

-- Normalized stats for an item link, or nil if unreadable.
-- What an item has that the score leaves out, as short labels: stats your
-- spec doesn't value (e.g. Intellect for a Rogue) and on-hit / on-use effects.
-- Armor is left out of the list: every piece has it.
local UNSCORED_SKIP = { RESISTANCE0_NAME = true }
function Stats.Unscored(raw, lines, weights)
  local out, seen = {}, {}
  local function add(label)
    if not seen[label] then seen[label] = true; out[#out + 1] = label end
  end
  local tokens = {}
  for token in pairs(raw or {}) do tokens[#tokens + 1] = token end
  table.sort(tokens)
  for _, token in ipairs(tokens) do
    local key = Stats.TOKEN_TO_KEY[token]
    local w = key and (key == "dps" or ns.Weights.For(weights, key))
    if not UNSCORED_SKIP[token] and not (w and w ~= 0) then
      add(key and Stats.LABELS[key] or Stats.TokenLabel(token))
    end
  end
  for _, line in ipairs(lines or {}) do
    if type(line) == "string" then
      if line:find("^Chance on hit:") then add("chance on hit effect") end
      if line:find("^Use:") then add("use effect") end
    end
  end
  return out
end

-- "ITEM_MOD_SPELL_POWER_SHORT" -> "Spell Power", "RESISTANCE4_NAME" -> "resistance"
function Stats.TokenLabel(token)
  if token:find("^RESISTANCE") then return "Resistance" end
  local words = token:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):lower():gsub("_", " ")
  return (words:gsub("^%l", string.upper))
end

function Stats.FromLink(link)
  local raw = ns.API.GetItemStats(link)
  if not raw then return nil end
  local stats = Stats.FromRaw(raw)
  return Stats.AddTooltipEffects(stats, ns.API.GetItemTooltipLines(link))
end
