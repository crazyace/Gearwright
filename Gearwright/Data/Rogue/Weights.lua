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

  assassination = { crit = 1.1, hit = 1.0, haste = 0.8, expertise = 0.8, sta = 0.2, rangedDps = 1 },
  combat        = { crit = 1.0, hit = 1.2, haste = 1.0, expertise = 1.0, sta = 0.2, rangedDps = 1 },
  subtlety      = { crit = 1.0, hit = 1.0, haste = 0.8, expertise = 0.8, sta = 0.2, rangedDps = 1 },
}

-- Agility per 1% crit, by level. Linear between known points.
-- 19: measured on the beta (66 Agility = 8.7% on the sheet).
-- 60: Classic's Rogue value, unconfirmed on Forever.
ns.Data.ROGUE.agiPerCrit = { { 19, 7.59 }, { 60, 29.0 } }
