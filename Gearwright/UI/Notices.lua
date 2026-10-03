-- Gearwright: chat notices for quest rewards, loot and rolls.
local _, ns = ...

local Notices = {}
ns.Notices = Notices

local UPGRADE = 0.5 -- attack-power equivalents; below this it's noise
local RETRY_REASONS = { ["stats-unreadable"] = true, ["equipped-unreadable"] = true }

local function enabled() return ns.db and ns.db.notices end

local function money(copper)
  if GetCoinTextureString then return GetCoinTextureString(copper) end
  return ("%dg %ds %dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

-- One row per link: { link, delta, slot, reqLevel } or { link, reason }.
-- `pending` is true when some item wasn't cached yet and a retry may help.
function Notices.Evaluate(links)
  local rows, pending = {}, false
  for i, link in ipairs(links) do
    local delta, slot, _, _, reqLevel = ns.Advisor.CompareToEquipped(link)
    if type(delta) == "number" then
      rows[i] = { link = link, delta = delta, slot = slot, reqLevel = reqLevel }
    else
      rows[i] = { link = link, reason = slot }
      if RETRY_REASONS[slot] then pending = true end
    end
  end
  return rows, pending
end

local function describe(row)
  local s = ("%s |cff40ff40+%.1f|r vs %s"):format(row.link, row.delta, ns.Advisor.SLOT_NAMES[row.slot] or "equipped")
  if row.reqLevel then s = s .. (" |cffff9900(at level %d)|r"):format(row.reqLevel) end
  return s
end

-- Quest rewards ----------------------------------------------------------------
-- Picks the best upgrade among the reward choices. With no upgrade, points at
-- the one that sells for the most.
function Notices.QuestRewards(retried)
  if not enabled() or not (GetNumQuestChoices and GetQuestItemLink) then return end
  local n = GetNumQuestChoices() or 0
  if n < 1 then return end
  local links = {}
  for i = 1, n do
    local link = ns.API.clean(GetQuestItemLink("choice", i))
    if not link then
      if not retried and C_Timer then C_Timer.After(1, function() Notices.QuestRewards(true) end) end
      return
    end
    links[i] = link
  end

  local rows, pending = Notices.Evaluate(links)
  if pending and not retried and C_Timer then
    C_Timer.After(1, function() Notices.QuestRewards(true) end)
    return
  end

  local best
  for i, row in ipairs(rows) do
    if row.delta and row.delta > UPGRADE and (not best or row.delta > best.delta) then
      best = row
      best.choice = i
    end
  end
  if best then
    ns.util.print("take reward %d: %s", best.choice, describe(best))
    return best
  end
  if n < 2 then return end

  local richest, price = nil, 0
  for i, link in ipairs(links) do
    local _, sell = ns.API.GetItemDetails(link)
    if sell and sell > price then richest, price = i, sell end
  end
  if richest then
    ns.util.print("no upgrade among the rewards; %s sells for the most (%s)", links[richest], money(price))
  else
    ns.util.print("no upgrade among the rewards")
  end
end

ns:On("QUEST_DETAIL", function() Notices.QuestRewards() end)
ns:On("QUEST_COMPLETE", function() Notices.QuestRewards() end)

-- Loot and rolls -----------------------------------------------------------------

local function announce(link, suffix)
  local rows = Notices.Evaluate({ link })
  local row = rows[1]
  if row.delta and row.delta > UPGRADE then
    ns.util.print("upgrade: %s%s", describe(row), suffix or "")
    return true
  end
end

function Notices.Loot()
  if not enabled() or not (GetNumLootItems and GetLootSlotLink) then return end
  local seen = {}
  for i = 1, GetNumLootItems() or 0 do
    local link = ns.API.clean(GetLootSlotLink(i))
    if link and not seen[link] then
      seen[link] = true
      announce(link)
    end
  end
end

function Notices.Roll(rollID)
  if not enabled() or not GetLootRollItemLink then return end
  local link = ns.API.clean(GetLootRollItemLink(rollID))
  if link then announce(link, " - worth a Need") end
end

ns:On("LOOT_OPENED", function() Notices.Loot() end)
ns:On("START_LOOT_ROLL", function(rollID) Notices.Roll(rollID) end)

-- Crafting ---------------------------------------------------------------------
-- /gearwright craft: every profession whose window has been opened on this
-- character (up to two primary professions on Forever, plus secondary ones).

local CRAFT_REASONS = {
  ["no-profession-open"] = "open each of your professions once so Gearwright can read its recipes",
  ["no-tradeskill-api"] = "this client has no profession API Gearwright knows",
}
local CRAFT_SHOWN = 8

function Notices.Craft(retried)
  local rows, professions, pending = ns.Advisor.CraftReport()
  if not rows then
    ns.util.print("craft: %s", CRAFT_REASONS[professions] or tostring(professions))
    return
  end
  local which = table.concat(professions, " and ")
  if pending > 0 and not retried and C_Timer then
    ns.util.print("reading %d %s items...", pending, which)
    C_Timer.After(2, function() Notices.Craft(true) end)
    return
  end
  if #rows == 0 then
    ns.util.print("no %s upgrades for you up to level %d", which,
      (ns.API.clean(UnitLevel("player")) or 0) + ns.Advisor.CRAFT_LOOKAHEAD)
  else
    ns.util.print("%s upgrades:", which)
    for i = 1, math.min(#rows, CRAFT_SHOWN) do
      local r = rows[i]
      local s = describe({ link = r.link or r.name or ("item " .. r.itemID), delta = r.delta, slot = r.slot, reqLevel = r.reqLevel })
      local tag = #professions > 1 and (" |cff999999[" .. r.profession .. "]|r") or ""
      print("  " .. s .. tag .. (r.learned and "" or " |cff999999(not learned)|r"))
    end
    if #rows > CRAFT_SHOWN then print(("  ...and %d more"):format(#rows - CRAFT_SHOWN)) end
  end
  if #professions == 1 then
    ns.util.print("only %s seen so far; if you have a second profession, open it once to include it", professions[1])
  end
  if pending > 0 then ns.util.print("%d items still not cached; run it again in a moment", pending) end
  return rows
end
