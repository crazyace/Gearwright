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
-- Melee crit and hit (the plain "critical strike" / "chance to hit" lines) do
-- nothing for spells in Classic, so they aren't scored.
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

-- Intellect per 1% spell crit. 60: Classic's Priest value; nothing measured on
-- Forever, so it's used at every level.
ns.Data.PRIEST.intPerSpellCrit = { { 60, 59.5 } }
