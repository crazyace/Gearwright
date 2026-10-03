-- Gearwright: recommended Rogue talent builds.
--
-- Keyed by talent NAME for now (English). The Traits API also gives spell IDs
-- (see docs/BETA-FINDINGS.md for the full tree), so switching to IDs for
-- locales is possible later. Names must match the tree exactly.
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
