-- Gearwright: consumables worth using: weapon buffs (sharpening stones,
-- weightstones, oils, Rogue poisons), elixirs, flasks and potions.
-- Shared by every class; Engine/Consumables.lua scores them with the spec's
-- weights and keeps the ones the player's level allows.
--
-- Effects and required levels are Classic's, read from Wowhead's Classic item
-- tooltips on 2026-10-04. What the beta confirms so far:
--   - the stones are Blacksmithing recipes and the oils Enchanting recipes
--     (2026-10-03 profession scans);
--   - healing potions are First Aid recipes on Forever, not Alchemy;
--   - the Rogue trainer's poison levels match Classic's (Instant Poison II 28,
--     Deadly Poison 30, ...; 2026-10-03 trainer scan).
-- Not seen on Forever yet: Alchemy (elixirs, flasks, mana potions), every
-- item's effect and required level, poison proc chances. Check in game.
--
-- weapon: what = "sharp" (swords, axes, daggers, polearms), "blunt" (maces,
--         staves, fist weapons) or "any" melee weapon; stats in Data/Stats.lua keys,
--         weaponDamage = flat damage added to each swing.
-- poisons: chance per hit; damage = average per proc, or for a DoT its total
--          over `duration` seconds, stacking up to `stacks`.
-- elixirs: one per group at a time (Classic: two agility elixirs don't stack,
--          an agility and a strength elixir do); "flask": one flask at a time.
-- potions: restores = "health" or "mana", amount = average.
local _, ns = ...

ns.Data.CONSUMABLES = {
  _status = "provisional",
  _updated = "2026-10-04",

  weapon = {
    { id = 2862, name = "Rough Sharpening Stone", level = 1, what = "sharp", stats = { weaponDamage = 2 }, source = "Blacksmithing" },
    { id = 2863, name = "Coarse Sharpening Stone", level = 5, what = "sharp", stats = { weaponDamage = 3 }, source = "Blacksmithing" },
    { id = 2871, name = "Heavy Sharpening Stone", level = 15, what = "sharp", stats = { weaponDamage = 4 }, source = "Blacksmithing" },
    { id = 7964, name = "Solid Sharpening Stone", level = 25, what = "sharp", stats = { weaponDamage = 6 }, source = "Blacksmithing" },
    { id = 12404, name = "Dense Sharpening Stone", level = 35, what = "sharp", stats = { weaponDamage = 8 }, source = "Blacksmithing" },
    { id = 18262, name = "Elemental Sharpening Stone", level = 50, what = "any", stats = { crit = 2 }, source = "Blacksmithing" },
    { id = 3239, name = "Rough Weightstone", level = 1, what = "blunt", stats = { weaponDamage = 2 }, source = "Blacksmithing" },
    { id = 3240, name = "Coarse Weightstone", level = 5, what = "blunt", stats = { weaponDamage = 3 }, source = "Blacksmithing" },
    { id = 3241, name = "Heavy Weightstone", level = 15, what = "blunt", stats = { weaponDamage = 4 }, source = "Blacksmithing" },
    { id = 7965, name = "Solid Weightstone", level = 25, what = "blunt", stats = { weaponDamage = 6 }, source = "Blacksmithing" },
    { id = 12643, name = "Dense Weightstone", level = 35, what = "blunt", stats = { weaponDamage = 8 }, source = "Blacksmithing" },
    { id = 20744, name = "Minor Wizard Oil", level = 5, what = "any", stats = { spellDamage = 8 }, source = "Enchanting" },
    { id = 20746, name = "Lesser Wizard Oil", level = 30, what = "any", stats = { spellDamage = 16 }, source = "Enchanting" },
    { id = 20750, name = "Wizard Oil", level = 40, what = "any", stats = { spellDamage = 24 }, source = "Enchanting" },
    { id = 20749, name = "Brilliant Wizard Oil", level = 45, what = "any", stats = { spellDamage = 36, spellCrit = 1 },
      source = "Enchanting" },
    { id = 20745, name = "Minor Mana Oil", level = 20, what = "any", stats = { mp5 = 4 }, source = "Enchanting" },
    { id = 20747, name = "Lesser Mana Oil", level = 40, what = "any", stats = { mp5 = 8 }, source = "Enchanting" },
    { id = 20748, name = "Brilliant Mana Oil", level = 45, what = "any", stats = { mp5 = 12, healing = 25 }, source = "Enchanting" },
  },

  -- Rogues make these themselves (the Poisons skill, from level 20).
  poisons = {
    class = "ROGUE",
    { id = 6947, name = "Instant Poison", level = 20, chance = 0.2, damage = 22 },
    { id = 6949, name = "Instant Poison II", level = 28, chance = 0.2, damage = 34 },
    { id = 6950, name = "Instant Poison III", level = 36, chance = 0.2, damage = 50 },
    { id = 8926, name = "Instant Poison IV", level = 44, chance = 0.2, damage = 76 },
    { id = 8927, name = "Instant Poison V", level = 52, chance = 0.2, damage = 105 },
    { id = 8928, name = "Instant Poison VI", level = 60, chance = 0.2, damage = 130 },
    { id = 2892, name = "Deadly Poison", level = 30, chance = 0.3, damage = 36, duration = 12, stacks = 5 },
    { id = 2893, name = "Deadly Poison II", level = 38, chance = 0.3, damage = 52, duration = 12, stacks = 5 },
    { id = 8984, name = "Deadly Poison III", level = 46, chance = 0.3, damage = 80, duration = 12, stacks = 5 },
    { id = 8985, name = "Deadly Poison IV", level = 54, chance = 0.3, damage = 108, duration = 12, stacks = 5 },
    { id = 20844, name = "Deadly Poison V", level = 60, chance = 0.3, damage = 136, duration = 12, stacks = 5 },
  },

  elixirs = {
    { id = 2457, name = "Elixir of Minor Agility", level = 2, group = "agility", stats = { agi = 4 } },
    { id = 3390, name = "Elixir of Lesser Agility", level = 18, group = "agility", stats = { agi = 8 } },
    { id = 8949, name = "Elixir of Agility", level = 27, group = "agility", stats = { agi = 15 } },
    { id = 9187, name = "Elixir of Greater Agility", level = 38, group = "agility", stats = { agi = 25 } },
    { id = 13452, name = "Elixir of the Mongoose", level = 46, group = "agility", stats = { agi = 25, crit = 2 } },
    { id = 2454, name = "Elixir of Lion's Strength", level = 1, group = "strength", stats = { str = 4 } },
    { id = 3391, name = "Elixir of Ogre's Strength", level = 20, group = "strength", stats = { str = 8 } },
    { id = 9206, name = "Elixir of Giants", level = 38, group = "strength", stats = { str = 25 } },
    { id = 3383, name = "Elixir of Wisdom", level = 10, group = "intellect", stats = { int = 6 } },
    { id = 9179, name = "Elixir of Greater Intellect", level = 37, group = "intellect", stats = { int = 25 } },
    { id = 9155, name = "Arcane Elixir", level = 37, group = "spell", stats = { spellDamage = 20 } },
    { id = 13454, name = "Greater Arcane Elixir", level = 47, group = "spell", stats = { spellDamage = 35 } },
    { id = 9264, name = "Elixir of Shadow Power", level = 40, group = "shadow", stats = { shadowDamage = 40 } },
    { id = 6373, name = "Elixir of Firepower", level = 18, group = "fire", stats = { fireDamage = 10 } },
    { id = 21546, name = "Elixir of Greater Firepower", level = 40, group = "fire", stats = { fireDamage = 40 } },
    { id = 17708, name = "Elixir of Frost Power", level = 28, group = "frost", stats = { frostDamage = 15 } },
    { id = 20007, name = "Mageblood Potion", level = 40, group = "mana", stats = { mp5 = 12 } },
    { id = 13512, name = "Flask of Supreme Power", level = 50, group = "flask", stats = { sp = 150 } },
  },

  potions = {
    { id = 118, name = "Minor Healing Potion", level = 1, restores = "health", amount = 80, source = "First Aid" },
    { id = 858, name = "Lesser Healing Potion", level = 3, restores = "health", amount = 160, source = "First Aid" },
    { id = 929, name = "Healing Potion", level = 12, restores = "health", amount = 320, source = "First Aid" },
    { id = 1710, name = "Greater Healing Potion", level = 21, restores = "health", amount = 520, source = "First Aid" },
    { id = 3928, name = "Superior Healing Potion", level = 35, restores = "health", amount = 800, source = "First Aid" },
    { id = 13446, name = "Major Healing Potion", level = 45, restores = "health", amount = 1400, source = "First Aid" },
    { id = 2455, name = "Minor Mana Potion", level = 5, restores = "mana", amount = 160 },
    { id = 3385, name = "Lesser Mana Potion", level = 14, restores = "mana", amount = 320 },
    { id = 3827, name = "Mana Potion", level = 22, restores = "mana", amount = 520 },
    { id = 6149, name = "Greater Mana Potion", level = 31, restores = "mana", amount = 800 },
    { id = 13443, name = "Superior Mana Potion", level = 41, restores = "mana", amount = 1200 },
    { id = 13444, name = "Major Mana Potion", level = 49, restores = "mana", amount = 1800 },
  },
}
