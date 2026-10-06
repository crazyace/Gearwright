-- Gearwright: Priest spec definitions.
local _, ns = ...
ns.Data.PRIEST = ns.Data.PRIEST or {}
local P = ns.Data.PRIEST

-- Talent tab index -> spec key (Classic's tab order).
P.tabToSpec = { [1] = "discipline", [2] = "holy", [3] = "shadow" }

-- Forever puts all three specs in one Traits tree (treeID 1114). Every node
-- carries exactly one of these group IDs, which says which spec it belongs to.
-- From the 2026-10-04 beta capture (data/probe/2026-10-04-priest.json, level 12
-- Gnome Priest); the tree-layout inference in Core/API.lua finds the same.
P.traitTabGroups = { [11608] = 1, [11615] = 2, [11622] = 3 }

-- What a Priest can equip, by item class -> subclass (Enum.ItemClass /
-- Enum.ItemWeaponSubclass / Enum.ItemArmorSubclass). Classic's list. On the
-- 2026-10-04 beta a level 12 Priest wore cloth, a one-handed mace and a wand;
-- staves and daggers are still unchecked.
P.proficiency = {
  [2] = { -- weapons
    [4] = true,  -- one-handed mace
    [10] = true, -- staff
    [15] = true, -- dagger
    [19] = true, -- wand
  },
  [4] = { [0] = true, [1] = true }, -- armor: misc (rings, necks, trinkets, off-hand items), cloth
}

-- Off-hand items ("Held In Off-hand": orbs, tomes) go in the off hand.
P.holdables = true

P.unlocks = {}

-- No dualWield entry: a one-hand weapon only goes in the main hand.

-- Spec to advise for before any talent point is spent (the first comes at
-- level 10). Priests level by damage (Smite, Shadow Word: Pain, a wand).
P.levelingSpec = "shadow"

P.specs = {
  discipline = {
    label = "Discipline",
    summary = "Shields and mana; Power Word: Shield, Inner Focus, Power Infusion.",
    icon = "Interface\\Icons\\Spell_Holy_PowerWordShield",
  },
  holy = {
    label = "Holy",
    summary = "Throughput healing; Spiritual Guidance turns Spirit into healing.",
    icon = "Interface\\Icons\\Spell_Holy_HolyBolt",
  },
  shadow = {
    label = "Shadow",
    summary = "Damage over time; Mind Flay, Shadowform, Vampiric Embrace.",
    icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
  },
}
