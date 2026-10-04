-- Gearwright: where items come from.
-- The Encounter Journal is empty on Forever, so dungeon loot comes from:
--   1. Gearwright's own table (Data/DungeonLoot.lua), built from drops the
--      probe has seen in game (tools/loot_from_probe.py);
--   2. Forever Dungeon Journal by Exehn: boss loot, trash drops and quest
--      rewards for every Forever dungeon. Used with Exehn's permission, with
--      credit. Gearwright ships a copy (Data/DungeonJournal.lua, from
--      tools/fdj_import.py); when the addon itself is installed, its live
--      table (ForeverDungeonJournal_NS.DB) is read instead, as it may be newer.
local _, ns = ...

local Sources = {}
ns.Sources = Sources

-- FDJ.DB -> flat list of { itemID, name, quality, dungeon, levels, kind, from, faction }
-- kind: "boss", "trash" or "quest". Pure: takes the table, touches no WoW API.
function Sources.FromDungeonJournal(db)
  local out = {}
  if type(db) ~= "table" then return out end
  for dungeon, d in pairs(db) do
    if type(d) == "table" then
      for _, boss in ipairs(d.bosses or {}) do
        for _, item in ipairs(boss.loot or {}) do
          if type(item) == "table" and type(item[1]) == "number" then
            out[#out + 1] = {
              itemID = item[1], name = item[2], quality = item[4], dungeon = dungeon, levels = d.level,
              kind = boss.trash and "trash" or "boss", from = boss.trash and "trash" or boss.name,
            }
          end
        end
      end
      for _, quest in ipairs(d.quests or {}) do
        for _, item in ipairs(quest.rewardItems or {}) do
          if type(item) == "table" and type(item[1]) == "number" then
            out[#out + 1] = {
              itemID = item[1], name = item[2], quality = item[3], dungeon = dungeon, levels = d.level,
              kind = "quest", from = quest.name, faction = quest.faction,
            }
          end
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.dungeon ~= b.dungeon then return a.dungeon < b.dungeon end
    return a.itemID < b.itemID
  end)
  return out
end

-- Gearwright's copy (Data/DungeonJournal.lua) -> the same shape.
function Sources.FromBundled(dj)
  local out = {}
  for dungeon, d in pairs(dj and dj.dungeons or {}) do
    for _, boss in ipairs(d.bosses or {}) do
      for _, item in ipairs(boss.loot or {}) do
        out[#out + 1] = { itemID = item[1], name = item[2], quality = item[4], dungeon = dungeon, levels = d.level,
          kind = boss.trash and "trash" or "boss", from = boss.trash and "trash" or boss.name }
      end
    end
    for _, q in ipairs(d.quests or {}) do
      for _, item in ipairs(q.rewards or {}) do
        out[#out + 1] = { itemID = item[1], name = item[2], quality = item[3], dungeon = dungeon, levels = d.level,
          kind = "quest", from = q.name, faction = q.faction }
      end
    end
  end
  table.sort(out, function(a, b)
    if a.dungeon ~= b.dungeon then return a.dungeon < b.dungeon end
    return a.itemID < b.itemID
  end)
  return out
end

-- Data/DungeonLoot.lua rows -> the same shape.
function Sources.FromOwnData(rows)
  local out = {}
  for _, r in ipairs(rows or {}) do
    out[#out + 1] = { itemID = r.itemID, name = r.name, dungeon = r.dungeon or "?", kind = "boss",
      from = r.from or "a monster", seen = r.count }
  end
  return out
end

local cache, index

-- Every known source, or nil when there are none.
function Sources.All()
  if cache then return cache end
  local own = Sources.FromOwnData(ns.Data.DUNGEON_LOOT)
  local db = ns.API.DungeonJournalDB()
  local journal = db and Sources.FromDungeonJournal(db) or Sources.FromBundled(ns.Data.DUNGEON_JOURNAL)
  if #own == 0 and #journal == 0 then return nil end
  cache = own
  for _, s in ipairs(journal) do cache[#cache + 1] = s end
  index = {}
  for _, s in ipairs(cache) do
    index[s.itemID] = index[s.itemID] or {}
    table.insert(index[s.itemID], s)
  end
  return cache
end

-- Sources of one item ID, or nil.
function Sources.For(itemID)
  if not Sources.All() then return nil end
  return index[itemID]
end

-- "Faldrim Anvilmar, Hall of Thanes (13-20)" / "quest: An Ancient Grudge, ..."
function Sources.Describe(s)
  local where = s.dungeon .. (s.levels and (" (" .. s.levels .. ")") or "")
  if s.kind == "quest" then return "quest " .. tostring(s.from) .. ", " .. where end
  if s.kind == "trash" then return "trash, " .. where end
  return tostring(s.from) .. ", " .. where
end

function Sources.Reset() cache, index = nil, nil end
