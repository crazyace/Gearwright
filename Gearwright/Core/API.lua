-- Gearwright: the ONLY file that talks to the WoW API for game data.
--
-- Forever runs on the Mainline (12.1.5-era) UI with Midnight's restrictions,
-- including "secret values" that addon code cannot read. Every read goes
-- through here so that when the probe tells us what works, we fix it once.
local _, ns = ...

local API = {}
ns.API = API

-- Secret values ---------------------------------------------------------------
function API.isSecret(v)
  return issecretvalue ~= nil and issecretvalue(v) == true
end

-- Returns v, or nil if the client handed us a secret value.
function API.clean(v)
  if API.isSecret(v) then return nil end
  return v
end

-- Items -----------------------------------------------------------------------
local getItemStats = (C_Item and C_Item.GetItemStats) or GetItemStats
local getItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-- The client can drop item data it already sent (it does on Forever when
-- hundreds of items are asked for), so what was read once is remembered for
-- the session: the live answer wins, the remembered one fills in when the
-- client has forgotten. Without this, upgrade lists flicker and keep asking.
local remembered = { stats = {}, details = {}, link = {}, tooltip = {} }
local function remember(kind, key, value)
  if key == nil then return value end
  if value ~= nil then remembered[kind][key] = value; return value end
  return remembered[kind][key]
end

-- Raw stat table keyed by ITEM_MOD_*_SHORT tokens, or nil.
function API.GetItemStats(link)
  if not link or not getItemStats then return nil end
  local ok, stats = pcall(getItemStats, link)
  if not ok or type(stats) ~= "table" then return remember("stats", link, nil) end
  local out = {}
  for token, value in pairs(stats) do
    local v = API.clean(value)
    if v then out[token] = v end
  end
  return remember("stats", link, out)
end

-- itemID, equipLoc, classID, subclassID for a link or ID. Works for uncached items.
function API.GetItemBasics(item)
  if not item or not getItemInfoInstant then return nil end
  local ok, itemID, _, _, equipLoc, _, classID, subclassID = pcall(getItemInfoInstant, item)
  if not ok then return nil end
  return itemID, equipLoc, classID, subclassID
end

-- requiredLevel, sellPrice (copper). Both nil until the item is cached.
function API.GetItemDetails(item)
  if not item or not getItemInfo then return nil end
  local ok, name, _, _, _, reqLevel, _, _, _, _, _, sellPrice = pcall(getItemInfo, item)
  local d
  if ok and name then d = { API.clean(reqLevel), API.clean(sellPrice) } end
  d = remember("details", item, d)
  if not d then return nil end
  return d[1], d[2]
end

-- Whose profession window is open: "mine", or "linked" (+ the player's name),
-- "guild", "npc" or "other" (a profession you don't have) for windows that
-- show someone else's recipes.
function API.TradeSkillOwner(profession)
  local ts = C_TradeSkillUI
  local function ask(fn)
    if not (ts and ts[fn]) then return nil end
    local ok, a, b = pcall(ts[fn])
    if ok then return API.clean(a), API.clean(b) end
  end
  local linked, who = ask("IsTradeSkillLinked")
  if linked then return "linked", who end
  if ask("IsTradeSkillGuild") then return "guild" end
  if ask("IsNPCCrafting") then return "npc" end
  local mine = API.PlayerProfessions()
  if next(mine) and profession and not mine[profession] then return "other" end
  return "mine"
end

-- Where the player stands: mapID, x, y (0-1), or nil.
function API.PlayerMapPosition()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local okM, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  mapID = okM and API.clean(mapID)
  if not mapID then return nil end
  local okP, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
  if not okP or not pos then return nil end
  local x, y
  if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
  x, y = API.clean(x), API.clean(y)
  if type(x) ~= "number" or type(y) ~= "number" then return nil end
  return mapID, x, y
end

-- The continent a map belongs to (its uiMapID), walking up C_Map's parents.
-- Classic IDs: Eastern Kingdoms 1415, Kalimdor 1414.
function API.ContinentOf(mapID)
  if not (mapID and C_Map and C_Map.GetMapInfo) then return nil end
  for _ = 1, 8 do
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    if not ok or type(info) ~= "table" then return nil end
    if info.mapType == 2 then return mapID end -- Enum.UIMapType.Continent
    if not info.parentMapID or info.parentMapID == 0 then return nil end
    mapID = info.parentMapID
  end
end

-- True when the item binds on pickup (so an alt can't craft it for you),
-- false when it doesn't, nil when not known yet.
function API.BindsOnPickup(item)
  if not item or not getItemInfo then return nil end
  local ok, name, _, _, _, _, _, _, _, _, _, _, _, _, bindType = pcall(getItemInfo, item)
  if not ok or not name or bindType == nil then return nil end
  return API.clean(bindType) == 1
end

-- What weights depend on: level, current main-hand DPS (buffs included) and
-- weapon speeds (flat weapon damage from an enchant is worth more on a slow weapon).
function API.CharacterSnapshot()
  local _, classToken = UnitClass("player")
  local char = { level = API.clean(UnitLevel("player")), class = API.clean(classToken) }
  if UnitDamage and UnitAttackSpeed then
    local okD, low, high = pcall(UnitDamage, "player")
    local okS, speed, offSpeed = pcall(UnitAttackSpeed, "player")
    low, high, speed, offSpeed = API.clean(low), API.clean(high), API.clean(speed), API.clean(offSpeed)
    if okD and okS and low and high and speed and speed > 0 then
      char.mainHandDps = (low + high) / 2 / speed
    end
    if okS and speed and speed > 0 then char.mainHandSpeed = speed end
    if okS and offSpeed and offSpeed > 0 then char.offHandSpeed = offSpeed end
  end
  return char
end

-- The item's link once cached, else nil.
function API.GetItemLink(item)
  if not item or not getItemInfo then return nil end
  local ok, name, link = pcall(getItemInfo, item)
  return remember("link", item, ok and name and API.clean(link) or nil)
end

-- Icon file ID for a link or ID. Works for uncached items.
function API.GetItemIcon(item)
  if not item or not getItemInfoInstant then return nil end
  local ok, _, _, _, _, icon = pcall(getItemInfoInstant, item)
  return ok and API.clean(icon) or nil
end

-- "Alliance" / "Horde", or nil.
function API.PlayerFaction()
  return UnitFactionGroup and API.clean(UnitFactionGroup("player")) or nil
end

-- Ask the client to cache an item; GET_ITEM_INFO_RECEIVED follows.
-- Ask the server for an item's data. Returns true while it's worth waiting
-- for: an item the server says doesn't exist, or that still hasn't arrived
-- after a few asks over 10 seconds, is given up on (some items in Gearwright's
-- lists don't exist on Forever), so lists stop "reading more items" forever.
local asked, gaveUp = {}, {}
local function now() return GetTime and GetTime() or 0 end

function API.RequestItem(itemID)
  if not itemID or gaveUp[itemID] then return false end
  if C_Item and C_Item.DoesItemExistByID then
    local ok, exists = pcall(C_Item.DoesItemExistByID, itemID)
    if ok and exists == false then gaveUp[itemID] = true; return false end
  end
  local a = asked[itemID]
  if not a then
    a = { n = 0, since = now() }
    asked[itemID] = a
  end
  a.n = a.n + 1
  if a.n > 3 and now() - a.since > 10 then
    gaveUp[itemID] = true
    return false
  end
  if C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, itemID)
  end
  return true
end

ns:On("GET_ITEM_INFO_RECEIVED", function(itemID, success)
  itemID = API.clean(itemID)
  if not itemID then return end
  if success == false then gaveUp[itemID] = true end
end)

-- Recipes -----------------------------------------------------------------------
-- The player's professions as { [name] = skillLevel }, from GetProfessions
-- (Mainline). Empty when the client has no such API.
function API.PlayerProfessions()
  local out = {}
  if not (GetProfessions and GetProfessionInfo) then return out end
  local ok, a, b, c, d, e, f = pcall(GetProfessions)
  if not ok then return out end
  for _, index in pairs({ a, b, c, d, e, f }) do
    local okI, name, _, skill = pcall(GetProfessionInfo, index)
    name = okI and API.clean(name)
    if name then out[name] = API.clean(skill) or 0 end
  end
  return out
end

-- Every recipe of the open profession window, learned or not:
--   { { recipeID=, name=, learned=, itemID= }, ... }, professionName   or nil, reason
function API.ReadRecipes()
  local ts = C_TradeSkillUI
  if not (ts and ts.GetAllRecipeIDs and ts.GetRecipeInfo) then return nil, "no-tradeskill-api" end
  local ok, ids = pcall(ts.GetAllRecipeIDs)
  if not ok or type(ids) ~= "table" or #ids == 0 then return nil, "no-profession-open" end
  local out = {}
  for _, id in ipairs(ids) do
    local okI, info = pcall(ts.GetRecipeInfo, id)
    info = okI and type(info) == "table" and info or {}
    local itemID
    if ts.GetRecipeSchematic then
      local okS, schematic = pcall(ts.GetRecipeSchematic, id, false)
      itemID = okS and type(schematic) == "table" and API.clean(schematic.outputItemID) or nil
    end
    out[#out + 1] = { recipeID = id, name = API.clean(info.name), learned = info.learned == true, itemID = itemID }
  end
  local profession
  if ts.GetBaseProfessionInfo then
    local okP, prof = pcall(ts.GetBaseProfessionInfo)
    profession = okP and type(prof) == "table" and API.clean(prof.professionName) or nil
  end
  return out, profession
end

-- Whether the player knows a spell (weapon skills are passive spells).
function API.KnowsSpell(spellID)
  local f = IsPlayerSpell or (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown
  if not f then return false end
  local ok, known = pcall(f, spellID)
  return ok and known == true
end

function API.GetEquippedLink(slot, unit)
  return API.clean(GetInventoryItemLink(unit or "player", slot))
end

-- The item in a bag slot, or nil.
function API.GetContainerItemLink(bag, slot)
  if not (bag and slot) then return nil end
  local cc = rawget(_G, "C_Container")
  local get = (cc and cc.GetContainerItemLink) or rawget(_G, "GetContainerItemLink")
  if not get then return nil end
  local ok, link = pcall(get, bag, slot)
  return ok and API.clean(link) or nil
end

-- Temporary weapon buffs (stones, oils, poisons): { [16] = minutes left or
-- false, [17] = ... }, or nil when the client has no GetWeaponEnchantInfo.
function API.GetWeaponBuffs()
  if not GetWeaponEnchantInfo then return nil end
  local ok, hasMain, mainMs, _, _, hasOff, offMs = pcall(GetWeaponEnchantInfo)
  if not ok then return nil end
  hasMain, mainMs, hasOff, offMs = API.clean(hasMain), API.clean(mainMs), API.clean(hasOff), API.clean(offMs)
  local function left(has, ms) return has and math.ceil((tonumber(ms) or 0) / 60000) or false end
  return { [16] = left(hasMain, mainMs), [17] = left(hasOff, offMs) }
end

-- Enchant ID embedded in an item link ("item:itemID:enchantID:..."), 0 if none.
function API.GetEnchantID(link)
  if not link then return nil end
  local enchant = link:match("item:%-?%d+:(%-?%d*)")
  return tonumber(enchant) or 0
end

-- Tooltip text lines for an item link. Used for "Equip:" effects that
-- GetItemStats may not report (e.g. "+1% hit" on Classic-style items).
function API.GetItemTooltipLines(link)
  if not link or not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil end
  local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return remember("tooltip", link, nil) end
  local lines = {}
  for _, line in ipairs(data.lines) do
    local text = API.clean(line.leftText)
    if type(text) == "string" and text ~= "" then lines[#lines + 1] = text end
  end
  -- An item not loaded yet shows "Retrieving item information": don't keep that.
  if #lines == 0 or (RETRIEVING_ITEM_INFO and lines[1] == RETRIEVING_ITEM_INFO) then
    return remember("tooltip", link, nil) or lines
  end
  return remember("tooltip", link, lines)
end

-- Talents -----------------------------------------------------------------------
-- Forever (beta 1.60.1) exposes talents through the Traits API: one tree holding
-- all three specs, readable, no secret values. Which spec a node belongs to is
-- given by a per-class group ID (Data/<Class>/Specs.lua: traitTabGroups). A class
-- without that map yet gets one worked out from the tree's layout (inferTabGroups).
-- The Classic API path is kept for clients that still have it.
--
-- Returns:
--   { source = "traits" | "classic",
--     tabs = { { name=, points=, talents = { {name=, rank=, max=, spellID=, nodeID=} } } } }
--   or nil, reason

local function spellName(spellID)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
  return GetSpellInfo and (GetSpellInfo(spellID))
end

local function nodeName(configID, info)
  local entryID = (info.activeEntry and info.activeEntry.entryID) or (info.entryIDs and info.entryIDs[1])
  local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
  local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
  if not def then return nil end
  return API.clean(def.overrideName) or (def.spellID and API.clean(spellName(def.spellID))), def.spellID
end

-- Spec group IDs for a class whose map isn't in its Data file yet. On the Rogue
-- capture every node carries exactly one spec group, alongside smaller groups
-- shared by a few nodes (12775-12789, one spec's tiers), and the three specs
-- sit side by side, left to right in tab order (posX 1020-2820, 5020-6820,
-- 9080-10880). So: take the biggest groups that don't overlap until every node
-- is covered, then number them left to right. Matches Data/Rogue/Specs.lua.
local function inferTabGroups(configID, treeIDs)
  local nodes, size = {}, {}
  for _, treeID in ipairs(treeIDs) do
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
      local info = C_Traits.GetNodeInfo(configID, nodeID)
      if info and info.groupIDs and #info.groupIDs > 0 then
        nodes[#nodes + 1] = info
        for _, g in ipairs(info.groupIDs) do size[g] = (size[g] or 0) + 1 end
      end
    end
  end
  local groups = {}
  for g in pairs(size) do groups[#groups + 1] = g end
  table.sort(groups, function(a, b)
    if size[a] ~= size[b] then return size[a] > size[b] end
    return a < b
  end)
  local taken, picked = {}, {}
  for _, g in ipairs(groups) do
    local members, clash = {}, false
    for i, info in ipairs(nodes) do
      for _, ng in ipairs(info.groupIDs) do
        if ng == g then
          if taken[i] then clash = true end
          members[#members + 1] = i
        end
      end
    end
    if not clash then
      local x = 0
      for _, i in ipairs(members) do taken[i] = true; x = x + (nodes[i].posX or 0) end
      picked[#picked + 1] = { group = g, x = x / #members }
    end
  end
  if #picked < 2 then return nil end
  table.sort(picked, function(a, b) return a.x < b.x end)
  local map = {}
  for tab, p in ipairs(picked) do map[p.group] = tab end
  return map
end

-- tabGroups: { [groupID] = tabIndex }, or nil to infer it. Nodes in none of the
-- groups are ignored.
local function readTraits(tabGroups)
  local configID = API.clean(C_ClassTalents.GetActiveConfigID())
  if not configID then return nil, "no-talent-config" end
  local config = C_Traits.GetConfigInfo(configID)
  local treeIDs = config and API.clean(config.treeIDs)
  if type(treeIDs) ~= "table" then return nil, "no-talent-config" end
  if not tabGroups then
    tabGroups = inferTabGroups(configID, treeIDs)
    if not tabGroups then return nil, "no-trait-tab-map" end
    if ns.db and ns.db.debug then
      local parts = {}
      for g, tab in pairs(tabGroups) do parts[#parts + 1] = ("[%d] = %d"):format(g, tab) end
      table.sort(parts)
      ns.util.debug("talent spec groups, from the tree layout: { %s }", table.concat(parts, ", "))
    end
  end

  local result = { source = "traits", tabs = {}, tabGroups = tabGroups }
  for _, tab in pairs(tabGroups) do
    for i = #result.tabs + 1, tab do result.tabs[i] = { points = 0, talents = {} } end
  end
  -- The Priest tree has a second "Holy Specialization" node far below the
  -- others (posY 21300, no tier groups): of two nodes with one name, keep
  -- the one with ranks, else the higher one, so builds see the real rank.
  local byName = {}
  for _, treeID in ipairs(treeIDs) do
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
      local info = C_Traits.GetNodeInfo(configID, nodeID)
      local tab
      for _, g in ipairs(info and info.groupIDs or {}) do tab = tab or tabGroups[g] end
      local name, spellID
      if tab then name, spellID = nodeName(configID, info) end
      if name then
        local rank = API.clean(info.activeRank) or API.clean(info.ranksPurchased) or 0
        local entry = result.tabs[tab]
        entry.points = entry.points + rank
        local t = {
          name = name, rank = rank, max = info.maxRanks, spellID = spellID, nodeID = nodeID,
          y = info.posY or 0, x = info.posX or 0,
        }
        local old = byName[name]
        if not old then
          byName[name] = t
          entry.talents[#entry.talents + 1] = t
        elseif t.rank > old.rank or (t.rank == old.rank and t.y < old.y) then
          for k, v in pairs(t) do old[k] = v end
        end
      end
    end
  end
  for _, entry in ipairs(result.tabs) do
    table.sort(entry.talents, function(a, b)
      if a.y ~= b.y then return a.y < b.y end
      return a.x < b.x
    end)
  end
  return result
end

local function readClassic()
  local result = { source = "classic", tabs = {} }
  for tab = 1, GetNumTalentTabs() do
    -- Return order of GetTalentTabInfo varies by client; take the first string.
    local a, b = GetTalentTabInfo(tab)
    local tabName = API.clean(type(a) == "string" and a or b)
    local entry = { name = tabName, points = 0, talents = {} }
    for i = 1, (GetNumTalents(tab) or 0) do
      local name, _, tier, column, rank, maxRank = GetTalentInfo(tab, i)
      name, rank = API.clean(name), API.clean(rank)
      if name then
        rank = rank or 0
        entry.points = entry.points + rank
        entry.talents[#entry.talents + 1] = {
          name = name, tier = tier, column = column, rank = rank, max = maxRank,
        }
      end
    end
    result.tabs[tab] = entry
  end
  return result
end

-- Reading the tree is ~160 API calls, and tooltips ask on every hover, so the
-- last good read is cached until a talent event says it changed.
API.TALENT_EVENTS = { "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED" }
local talentCache = {}
for _, event in ipairs(API.TALENT_EVENTS) do
  ns:On(event, function() talentCache = {} end)
end

function API.ReadTalents(tabGroups)
  local key = tabGroups or "none"
  if talentCache[key] then return talentCache[key] end
  local result, reason
  if C_ClassTalents and C_Traits then
    local ok, r, why = pcall(readTraits, tabGroups)
    if ok then
      result, reason = r, why
    else
      result, reason = nil, "traits-error"
      ns.util.debug("talent read failed: %s", tostring(r))
    end
  elseif GetNumTalentTabs and GetTalentInfo then
    result = readClassic()
  else
    reason = "no-talent-api"
  end
  talentCache[key] = result
  return result, reason
end
