-- Gearwright: Rogue stat weights, normalized so Agility = 1.0.
--
-- !!! PROVISIONAL !!!
-- These are starting guesses, not results. Nobody has published Forever Rogue
-- stat priorities yet. Replace with values from beta testing, logs, or a sim.
-- Hit/crit/haste/expertise are "per 1%" until the probe confirms the units.
local _, ns = ...
ns.Data.ROGUE = ns.Data.ROGUE or {}

ns.Data.ROGUE.weights = {
  _status = "provisional",
  _updated = "2026-10-03",

  assassination = {
    agi = 1.00, str = 0.50, ap = 0.50, sta = 0.05,
    hit = 10.0, crit = 11.0, haste = 8.0, expertise = 8.0,
    dps = 5.0, -- main-hand weapon DPS matters less with poisons doing work
  },
  combat = {
    agi = 1.00, str = 0.50, ap = 0.50, sta = 0.05,
    hit = 12.0, crit = 9.0, haste = 9.0, expertise = 10.0,
    dps = 8.0,
  },
  subtlety = {
    agi = 1.00, str = 0.50, ap = 0.50, sta = 0.05,
    hit = 10.0, crit = 10.0, haste = 7.0, expertise = 8.0,
    dps = 7.0,
  },
}
