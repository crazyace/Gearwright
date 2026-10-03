-- Gearwright: recommended Rogue talent builds.
--
-- Keyed by talent NAME for now (English). Switch to talent/spell IDs once the
-- probe confirms which IDs the Forever client exposes, so locales work.
-- Fill these from /gwp talents output on a beta Rogue.
local _, ns = ...
ns.Data.ROGUE = ns.Data.ROGUE or {}

ns.Data.ROGUE.builds = {
  assassination = {
    status = "todo",
    level = 60,
    notes = "Raid DPS. Core: Mutilate, Venom, Cold Blood.",
    talents = {
      -- ["Mutilate"] = 1,
      -- ["Venom"] = 1,
    },
  },
  combat = {
    status = "todo",
    level = 60,
    notes = "Raid DPS. Core: Hack and Slash, Restless Blades, Adrenaline Rush.",
    talents = {
      -- ["Hack and Slash"] = 5,
      -- ["Restless Blades"] = 1,
    },
  },
  subtlety = {
    status = "todo",
    level = 60,
    notes = "Bleed/opener spec. Core: Hemorrhage, Serrated Blades, Thousand Cuts.",
    talents = {
      -- ["Hemorrhage"] = 1,
    },
  },
}
