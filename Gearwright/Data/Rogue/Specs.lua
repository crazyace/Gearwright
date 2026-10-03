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

-- What a Rogue can equip, by item class -> subclass (Enum.ItemClass /
-- Enum.ItemWeaponSubclass / Enum.ItemArmorSubclass). From Classic; Forever
-- may differ, e.g. if Rogues gain axes.
R.proficiency = {
  [2] = { -- weapons
    [15] = true, -- dagger
    [7] = true,  -- one-handed sword
    [4] = true,  -- one-handed mace
    [13] = true, -- fist weapon
    [2] = true, [3] = true, [18] = true, [16] = true, -- bow, gun, crossbow, thrown
  },
  [4] = { [0] = true, [1] = true, [2] = true }, -- armor: misc (rings, necks, trinkets), cloth, leather
}

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
