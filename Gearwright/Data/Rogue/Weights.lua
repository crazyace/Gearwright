-- Gearwright: Rogue stat weights.
--
-- Scores are in attack-power equivalents: "this item is worth N attack power".
-- Engine/Weights.lua turns these per-spec numbers into a full weight table
-- for the player's current level and damage.
--
-- Confirmed on the beta (2026-10-03 character sheet, level 19):
--   1 Strength = 1 AP; 1 Agility = 1 AP plus crit (and armor/dodge, not scored).
-- From Classic's formulas, not yet checked on Forever:
--   melee DPS = weapon DPS + AP / 14, so 1 weapon DPS = 14 AP; the off hand hits for 50%.
--
-- !!! PROVISIONAL !!!
-- The per-spec numbers below are guesses. Rating stats (hit, crit, haste,
-- expertise) are "per 1%" until the probe confirms the units, and say how much
-- of your damage 1% is worth: crit = 1.0 means 1% crit ~ 1% more damage.
local _, ns = ...
ns.Data.ROGUE = ns.Data.ROGUE or {}

ns.Data.ROGUE.weights = {
  _status = "provisional",
  _updated = "2026-10-03",

  assassination = { crit = 1.1, hit = 1.0, haste = 0.8, expertise = 0.8, sta = 0.2, rangedDps = 1, abilityHits = 0.15 },
  combat        = { crit = 1.0, hit = 1.2, haste = 1.0, expertise = 1.0, sta = 0.2, rangedDps = 1, abilityHits = 0.15 },
  subtlety      = { crit = 1.0, hit = 1.0, haste = 0.8, expertise = 0.8, sta = 0.2, rangedDps = 1, abilityHits = 0.15 },
}
-- abilityHits: main-hand weapon hits per second from abilities, which makes a
-- slow main hand worth more than its DPS (Engine/Weights.lua, WeaponHit).
-- 10 energy a second, about 60% of it on builders: Combat's Sinister Strike
-- (40 energy, 100% weapon damage) is 0.15 hits a second; Backstab (60 energy,
-- 150%) works out the same. Classic's numbers, not measured on Forever.

-- Agility per 1% crit comes from Forever's own per-level table
-- (Data/ClassStats.lua): 7.6 at level 19, as the beta's character sheet showed.

-- Talents that change what a stat is worth (Engine/Weights.lua, TalentEffects).
-- Amounts are Wowhead Forever's talent text (2026-10-06). Not checked in game
-- yet: `/gwp talents` records each talent's text at rank 1, your rank and max
-- rank. Talents that add crit or hit chance (Malice, Precision) don't change
-- what one more point is worth, so they aren't here.
ns.Data.ROGUE.talentEffects = {
  -- "Increases the critical strike damage bonus of your Sinister Strike, Gouge,
  -- Backstab, Mutilate, Ghostly Strike, and Hemorrhage abilities by 6%."
  -- Classic's is 6% per rank too. Those abilities are about half your damage.
  { name = "Lethality", stat = "crit", kind = "scale", amount = 0.06, perRank = true, share = 0.5,
    note = "crits hit harder" },
}
