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

-- Raw stat table keyed by ITEM_MOD_*_SHORT tokens, or nil.
function API.GetItemStats(link)
  if not link or not getItemStats then return nil end
  local ok, stats = pcall(getItemStats, link)
  if not ok or type(stats) ~= "table" then return nil end
  local out = {}
  for token, value in pairs(stats) do
    local v = API.clean(value)
    if v then out[token] = v end
  end
  return out
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
  if not ok or not name then return nil end
  return API.clean(reqLevel), API.clean(sellPrice)
end

-- What weights depend on: level, current main-hand DPS (buffs included) and
-- weapon speeds (flat weapon damage from an enchant is worth more on a slow weapon).
function API.CharacterSnapshot()
  local char = { level = API.clean(UnitLevel("player")) }
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
  if not ok or not name then return nil end
  return API.clean(link)
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

-- Forever Dungeon Journal's dungeon table when that addon is loaded, else nil.
function API.DungeonJournalDB()
  local fdj = rawget(_G, "ForeverDungeonJournal_NS")
  return type(fdj) == "table" and type(fdj.DB) == "table" and fdj.DB or nil
end

-- Ask the client to cache an item; GET_ITEM_INFO_RECEIVED follows.
function API.RequestItem(itemID)
  if itemID and C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, itemID)
  end
end

-- Recipes -----------------------------------------------------------------------
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

function API.GetEquippedLink(slot, unit)
  return API.clean(GetInventoryItemLink(unit or "player", slot))
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
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
  local lines = {}
  for _, line in ipairs(data.lines) do
    local text = API.clean(line.leftText)
    if type(text) == "string" and text ~= "" then lines[#lines + 1] = text end
  end
  return lines
end

-- Talents -----------------------------------------------------------------------
-- Forever (beta 1.60.1) exposes talents through the Traits API: one tree holding
-- all three specs, readable, no secret values. Which spec a node belongs to is
-- given by a per-class group ID (Data/<Class>/Specs.lua: traitTabGroups).
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

-- tabGroups: { [groupID] = tabIndex }. Nodes in none of the groups are ignored.
local function readTraits(tabGroups)
  if not tabGroups then return nil, "no-trait-tab-map" end
  local configID = API.clean(C_ClassTalents.GetActiveConfigID())
  if not configID then return nil, "no-talent-config" end
  local config = C_Traits.GetConfigInfo(configID)
  local treeIDs = config and API.clean(config.treeIDs)
  if type(treeIDs) ~= "table" then return nil, "no-talent-config" end

  local result = { source = "traits", tabs = {} }
  for _, tab in pairs(tabGroups) do
    for i = #result.tabs + 1, tab do result.tabs[i] = { points = 0, talents = {} } end
  end
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
        entry.talents[#entry.talents + 1] = {
          name = name, rank = rank, max = info.maxRanks, spellID = spellID, nodeID = nodeID,
          y = info.posY or 0, x = info.posX or 0,
        }
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
