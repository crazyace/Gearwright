-- Gearwright: Rogue spec definitions.
local _, ns = ...
ns.Data.ROGUE = ns.Data.ROGUE or {}
local R = ns.Data.ROGUE

-- Talent tab index -> spec key.
R.tabToSpec = { [1] = "assassination", [2] = "combat", [3] = "subtlety" }

-- Forever puts all three specs in one Traits tree (treeID 1111). Every node
-- carries exactly one of these group IDs, which says which spec it belongs to.
-- From the 2026-10-03 beta capture (data/probe/2026-10-03-assassination.json).
R.traitTabGroups = { [11580] = 1, [11573] = 2, [11572] = 3 }

R.specs = {
  assassination = {
    label = "Assassination",
    summary = "Poison-focused; built around Mutilate and Venom.",
    weapons = { mainHand = "dagger", offHand = "dagger" }, -- Mutilate wants daggers
  },
  combat = {
    label = "Combat",
    summary = "Dual-wield melee; Restless Blades cooldown loop.",
    weapons = { mainHand = "any", offHand = "any" }, -- Hack and Slash covers all types
  },
  subtlety = {
    label = "Subtlety",
    summary = "Stealth openers; Hemorrhage feeds your Rupture.",
    weapons = { mainHand = "dagger", offHand = "any" },
  },
}
