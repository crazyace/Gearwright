-- Gearwright: weapon masters, the trainers who teach weapon skills.
--
-- Seeded from Classic (NPC, city, what they teach). Forever may have moved or
-- added some: these are NOT checked in game yet. Gearwright corrects itself:
-- whenever you open a trainer that teaches a weapon skill, its real position
-- and skill list are saved (Engine/Trainers.lua) and used instead.
--
-- mapID: Classic/Forever uiMapID (Stormwind 1453, Orgrimmar 1454, Ironforge 1455,
-- Thunder Bluff 1456, Darnassus 1457, Undercity 1458); x, y: 0-1 map position.
local _, ns = ...

ns.Data.WEAPON_MASTERS = {
  { npcID = 11867, name = "Woo Ping", faction = "Alliance", mapID = 1453, x = 0.572, y = 0.576,
    city = "Stormwind", skills = { "Daggers", "One-Handed Swords", "Two-Handed Swords", "Polearms", "Staves", "Crossbows" } },
  { npcID = 11865, name = "Buliwyf Stonehand", faction = "Alliance", mapID = 1455, x = 0.612, y = 0.895,
    city = "Ironforge", skills = { "Fist Weapons", "Guns", "One-Handed Axes", "Two-Handed Axes", "One-Handed Maces", "Two-Handed Maces" } },
  { npcID = 13084, name = "Bixi Wobblebonk", faction = "Alliance", mapID = 1455, x = 0.622, y = 0.888,
    city = "Ironforge", skills = { "Daggers", "Crossbows", "Thrown" } },
  { npcID = 11866, name = "Ilyenia Moonfire", faction = "Alliance", mapID = 1457, x = 0.576, y = 0.466,
    city = "Darnassus", skills = { "Daggers", "Fist Weapons", "Bows", "Staves", "Thrown" } },
  { npcID = 11868, name = "Sayoc", faction = "Horde", mapID = 1454, x = 0.815, y = 0.196,
    city = "Orgrimmar", skills = { "Daggers", "Fist Weapons", "Bows", "Thrown", "One-Handed Axes", "Two-Handed Axes" } },
  { npcID = 2704, name = "Hanashi", faction = "Horde", mapID = 1454, x = 0.812, y = 0.190,
    city = "Orgrimmar", skills = { "Bows", "Staves", "Thrown", "One-Handed Axes", "Two-Handed Axes" } },
  { npcID = 11869, name = "Ansekhwa", faction = "Horde", mapID = 1456, x = 0.406, y = 0.626,
    city = "Thunder Bluff", skills = { "Guns", "Staves", "One-Handed Maces", "Two-Handed Maces" } },
  { npcID = 11870, name = "Archibald", faction = "Horde", mapID = 1458, x = 0.574, y = 0.328,
    city = "Undercity", skills = { "Daggers", "Crossbows", "Polearms", "One-Handed Swords", "Two-Handed Swords" } },
}
