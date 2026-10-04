-- Gearwright: weapon masters, the trainers who teach weapon skills.
--
-- Seeded from Classic (NPC, city, what they teach). Forever may have moved or
-- added some: only entries with `checked = true` have been confirmed in game. Gearwright corrects itself:
-- whenever you open a trainer that teaches a weapon skill, its real position
-- and skill list are saved (Engine/Trainers.lua) and used instead.
--
-- mapID: Classic/Forever uiMapID (Stormwind 1453, Orgrimmar 1454, Ironforge 1455,
-- Thunder Bluff 1456, Darnassus 1457, Undercity 1458); x, y: 0-1 map position;
-- continent: Eastern Kingdoms 1415, Kalimdor 1414; detail: how to find them there.
local _, ns = ...

ns.Data.WEAPON_MASTERS = {
  -- Woo Ping: checked on the Forever beta, 2026-10-03 (probe at his window: 63.9, 69.0).
  { npcID = 11867, name = "Woo Ping", faction = "Alliance", mapID = 1453, x = 0.639, y = 0.690, checked = true,
    city = "Stormwind", continent = 1415, detail = "inside the Just Maces shop",
    skills = { "Daggers", "One-Handed Swords", "Two-Handed Swords", "Polearms", "Staves", "Crossbows" } },
  -- Buliwyf and Bixi: in the Timberline Arms weapon shop, per an Ironforge guard;
  -- positions from the probe at their windows (2026-10-03, 61.3, 89.4 and 62.1, 89.5).
  { npcID = 11865, name = "Buliwyf Stonehand", faction = "Alliance", mapID = 1455, x = 0.613, y = 0.894, checked = true,
    city = "Ironforge", continent = 1415, detail = "in the Timberline Arms weapon shop",
    skills = { "Fist Weapons", "Guns", "One-Handed Axes", "Two-Handed Axes", "One-Handed Maces", "Two-Handed Maces" } },
  { npcID = 13084, name = "Bixi Wobblebonk", faction = "Alliance", mapID = 1455, x = 0.621, y = 0.895, checked = true,
    city = "Ironforge", continent = 1415, detail = "in the Timberline Arms weapon shop",
    skills = { "Daggers", "Crossbows", "Thrown" } },
  { npcID = 11866, name = "Ilyenia Moonfire", faction = "Alliance", mapID = 1457, x = 0.576, y = 0.466,
    city = "Darnassus", continent = 1414,
    skills = { "Daggers", "Fist Weapons", "Bows", "Staves", "Thrown" } },
  { npcID = 11868, name = "Sayoc", faction = "Horde", mapID = 1454, x = 0.815, y = 0.196,
    city = "Orgrimmar", continent = 1414,
    skills = { "Daggers", "Fist Weapons", "Bows", "Thrown", "One-Handed Axes", "Two-Handed Axes" } },
  { npcID = 2704, name = "Hanashi", faction = "Horde", mapID = 1454, x = 0.812, y = 0.190,
    city = "Orgrimmar", continent = 1414,
    skills = { "Bows", "Staves", "Thrown", "One-Handed Axes", "Two-Handed Axes" } },
  { npcID = 11869, name = "Ansekhwa", faction = "Horde", mapID = 1456, x = 0.406, y = 0.626,
    city = "Thunder Bluff", continent = 1414,
    skills = { "Guns", "Staves", "One-Handed Maces", "Two-Handed Maces" } },
  { npcID = 11870, name = "Archibald", faction = "Horde", mapID = 1458, x = 0.574, y = 0.328,
    city = "Undercity", continent = 1415,
    skills = { "Daggers", "Crossbows", "Polearms", "One-Handed Swords", "Two-Handed Swords" } },
}
