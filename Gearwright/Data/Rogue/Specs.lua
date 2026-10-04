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
-- Enum.ItemWeaponSubclass / Enum.ItemArmorSubclass). From Classic, plus what
-- R.unlocks below adds.
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

-- Weapon skills, by weapon subclass. As in Classic, a Rogue starts with Daggers
-- (and Thrown) and trains the others at a weapon master: on the 2026-10-03 beta
-- a level 19 Rogue knew Daggers, Thrown and Dual Wield but not Swords, Maces or
-- Fist Weapons (IsPlayerSpell). A weapon whose skill isn't trained yet is still
-- scored, with a note to train it.
R.weaponSkills = {
  [15] = { spell = 1180, name = "Daggers" },
  [7] = { spell = 201, name = "One-Handed Swords" },
  [4] = { spell = 198, name = "One-Handed Maces" },
  [13] = { spell = 15590, name = "Fist Weapons" },
  [0] = { spell = 196, name = "One-Handed Axes" },
  [2] = { spell = 264, name = "Bows" },
  [3] = { spell = 266, name = "Guns" },
  [18] = { spell = 5011, name = "Crossbows" },
  [16] = { spell = 2567, name = "Thrown" },
}

-- Weapon types a Rogue only gets later. Forever's Combat talent Hack and Slash
-- has an Axe/Sword bonus, so taking it should let Rogues use one-handed axes.
-- Unlocked when the talent has a point in it, or when the player knows the
-- weapon skill spell (One-Handed Axes, 196), whichever the client shows first.
R.unlocks = {
  { class = 2, subclass = 0, talent = "Hack and Slash", spell = 196 }, -- one-handed axe
}

-- Rogues learn Dual Wield (spell 674) at level 10; before that a weapon can
-- only go in the main hand.
R.dualWield = { level = 10, spell = 674 }

-- Spec to advise for before any talent point is spent (the first comes at
-- level 10). Combat takes any weapon in either hand, so nothing is ruled out.
R.levelingSpec = "combat"

R.specs = {
  assassination = {
    label = "Assassination",
    summary = "Poison-focused; built around Mutilate and Venom.",
    -- Backstab needs a main-hand dagger. Forever's Mutilate has no dagger
    -- requirement (Wowhead spell 1310707, 2026-10-03), so the off hand is free.
    weapons = { mainHand = "dagger", offHand = "any" },
  },
  combat = {
    label = "Combat",
    summary = "Dual-wield melee; Restless Blades cooldown loop.",
    weapons = { mainHand = "any", offHand = "any" }, -- Hack and Slash covers all types
  },
  subtlety = {
    label = "Subtlety",
    summary = "Stealth openers; Hemorrhage feeds your Rupture.",
    weapons = { mainHand = "dagger", offHand = "any" }, -- Backstab and Ambush
  },
}
