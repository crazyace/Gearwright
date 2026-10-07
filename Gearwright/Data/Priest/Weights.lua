-- Gearwright: Priest stat weights.
--
-- Priests are casters (model = "caster", Engine/Weights.lua BuildCaster): scores
-- are in points of the spec's main power. Discipline and Holy: "this item is
-- worth N healing". Shadow: "worth N spell damage". Spell power (damage AND
-- healing) is worth healing + spellDamage.
--
-- !!! PROVISIONAL !!!
-- Every number is a Classic rule of thumb, nothing is measured on Forever yet:
--   1 mp5 ~ 2 healing for a healer; Intellect and Spirit are mana, worth well
--   under a point of power each; Holy values Spirit most (Spiritual Guidance).
-- Rating stats (spellHit, spellCrit, haste) say how much of your output 1% is
-- worth, like the Rogue's: healers' crits heal for 150%, so 1% crit ~ 0.5%.
-- Crit is one stat on Forever (melee, ranged and spells, per Blizzard), so the
-- plain "critical strike" line counts as spell crit. Melee hit still isn't
-- scored: nothing says hit was merged too.
local _, ns = ...
ns.Data.PRIEST = ns.Data.PRIEST or {}

ns.Data.PRIEST.weights = {
  _status = "provisional",
  _updated = "2026-10-04",
  model = "caster",

  discipline = { healing = 1, spellDamage = 0.4, int = 0.6, spi = 0.5, mp5 = 2.0, sta = 0.15,
                 spellCrit = 0.5, spellHit = 0.2, haste = 0.7, wandDps = 0.5, schools = { holy = true, shadow = true } },
  holy       = { healing = 1, spellDamage = 0.15, int = 0.6, spi = 0.7, mp5 = 2.2, sta = 0.1,
                 spellCrit = 0.5, spellHit = 0.05, haste = 0.6, wandDps = 0.5, schools = { holy = true, shadow = true } },
  shadow     = { spellDamage = 1, healing = 0.1, int = 0.35, spi = 0.5, mp5 = 1.0, sta = 0.3,
                 spellCrit = 0.3, spellHit = 1.0, haste = 0.9, wandDps = 1.5, schools = { shadow = true } },
}

-- Points of power that 1% of your output is worth, by level. From Classic's
-- spells: 1% of a level-20 Heal (~320) or Mind Blast (~110) is ~3 points
-- after the spell's coefficient; 1% of a level-60 Greater Heal (~1000) or
-- Mind Blast (~540) is ~12.
ns.Data.PRIEST.powerPerPercent = { { 20, 3 }, { 60, 12 } }

-- Intellect per 1% spell crit comes from Forever's own per-level table
-- (Data/ClassStats.lua): 9.5 at level 12, as the beta's character sheet showed.

-- Talents that change what a stat is worth (Engine/Weights.lua, TalentEffects).
-- Amounts are Wowhead Forever's talent text (2026-10-06), taken as the value at
-- max rank unless perRank. Not checked in game yet: `/gwp talents` records each
-- talent's text at rank 1, your rank and max rank, which settles it.
-- Talents that add hit (Holy Precision, Shadow Focus) aren't here: the weights
-- don't model the hit cap yet.
ns.Data.PRIEST.talentEffects = {
  -- "Increases your total Intellect by 15%." (Classic: +2% mana per rank)
  { name = "Mental Strength", stat = "int", kind = "mult", amount = 0.15, note = "Intellect +15%" },
  -- "Allows 50% of your Mana regeneration to continue while casting."
  { name = "Meditation", stat = "spi", kind = "scale", amount = 0.5, note = "Spirit regen while casting" },
  -- "Increases your spell healing by up to 25% of your total Spirit and your
  -- spell damage by up to 8% of your total Spirit."
  { name = "Spiritual Guidance", stat = "spi", kind = "from", amount = 0.25, into = { healing = 1, spellDamage = 0.32 },
    note = "Spirit adds healing and spell damage" },
  -- "...increasing the critical strike damage bonus of your Shadow spells by 100%"
  { name = "Shadowform", stat = "spellCrit", kind = "scale", amount = 1.0, note = "Shadow crits hit harder" },
}
