-- Gearwright: recommended Rogue enchants per slot.
--
-- Enchanting was overhauled in Forever, so Classic lists don't carry over.
-- Collect real enchant IDs with GearwrightProbe (gear scan reads the enchant
-- ID out of each equipped item link; /gwp scans recipes when you open Enchanting).
--
-- Schema:
--   [slotID] = { enchantID = <number>, name = "<display name>", note = "<optional>" }
-- Slot IDs: 1 Head, 3 Shoulder, 5 Chest, 7 Legs, 8 Feet, 9 Wrist, 10 Hands,
--           15 Back, 16 Main Hand, 17 Off Hand
local _, ns = ...
ns.Data.ROGUE = ns.Data.ROGUE or {}

ns.Data.ROGUE.enchants = {
  _status = "todo",
  assassination = {
    -- [16] = { enchantID = 0000, name = "Example: Crusader", note = "verify in Forever" },
  },
  combat = {},
  subtlety = {},
}
