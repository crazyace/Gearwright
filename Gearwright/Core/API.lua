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

-- itemID, equipLoc for a link or ID.
function API.GetItemBasics(item)
  if not item or not getItemInfoInstant then return nil end
  local ok, itemID, _, _, equipLoc = pcall(getItemInfoInstant, item)
  if not ok then return nil end
  return itemID, equipLoc
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
-- Forever keeps Classic-shaped trees (3 tabs, 31-point style), but which API
-- exposes them on the Forever client is UNCONFIRMED. GearwrightProbe answers this.
--
-- Returns:
--   { source = "classic", tabs = { { name=, points=, talents = { {name=, tier=, column=, rank=, max=} } } } }
--   or nil, reason
function API.ReadTalents()
  if GetNumTalentTabs and GetTalentInfo then
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

  if C_ClassTalents and C_Traits then
    -- TODO(phase 0): implement once the probe shows how Forever maps
    -- its trees onto the Traits system.
    return nil, "traits-api-not-implemented"
  end

  return nil, "no-talent-api"
end
