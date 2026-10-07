-- Gearwright: chat notices for quest rewards, loot and rolls.
local _, ns = ...

local Notices = {}
ns.Notices = Notices

local UPGRADE = 0.5 -- attack power (or spell power) points; below this it's noise
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
  local s = ("%s |cff40ff40%s|r vs %s"):format(row.link, ns.Advisor.FormatScore(row.delta, true),
    ns.Advisor.SLOT_NAMES[row.slot] or "equipped")
  if row.reqLevel then s = s .. (" |cffff9900(at level %d)|r"):format(row.reqLevel) end
  return s
end

-- Quest rewards ----------------------------------------------------------------
-- Picks the best upgrade among the reward choices. With no upgrade, points at
-- the one that sells for the most.
function Notices.QuestRewards(retried)
  if not (GetNumQuestChoices and GetQuestItemLink) then return end
  local n = GetNumQuestChoices() or 0
  if n < 1 then return ns.QuestHighlight.Hide() end
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

  -- The pick is the best upgrade you can use now; one the window tints red
  -- (can't use it yet) is shown greyed, and named if it would have won.
  local best, blocked
  for i, row in ipairs(rows) do
    row.usable = ns.API.QuestChoiceUsable(i)
    if row.delta and row.delta > UPGRADE then
      row.choice = i
      if not row.usable then
        if not blocked or row.delta > blocked.delta then blocked = row end
      elseif not best or row.delta > best.delta then
        best = row
      end
    end
  end
  if blocked and best and blocked.delta <= best.delta then blocked = nil end
  local richest, price
  if not best and n > 1 then
    price = 0
    for i, link in ipairs(links) do
      local _, sell = ns.API.GetItemDetails(link)
      if sell and sell > price then richest, price = i, sell end
    end
  end
  -- The quest window draws its buttons after this event: mark them next frame.
  local function highlight() ns.QuestHighlight.Show(rows, best and best.choice, richest, UPGRADE) end
  if C_Timer then C_Timer.After(0, highlight) else highlight() end

  if not enabled() then return best end
  if blocked then
    ns.util.print("reward %d would be %s, but you can't use it yet", blocked.choice, describe(blocked))
  end
  if best then
    ns.util.print("take reward %d: %s", best.choice, describe(best))
    return best
  end
  if blocked then return end
  if n < 2 then return end
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

-- Wishlist items that just became wearable.
function Notices.WishlistLevelUp(level)
  if not enabled() then return end
  local ready = {}
  for _, w in ipairs(ns.Wishlist.Report()) do
    if not w.equipped and w.reqLevel == level and w.delta and w.delta > 0.05 then
      ready[#ready + 1] = ("%s (|cff40ff40%s|r)"):format(w.link or w.entry.name or "?", ns.Advisor.FormatScore(w.delta, true))
    end
  end
  if #ready > 0 then ns.util.print("wishlist: you can wear %s now", table.concat(ready, ", ")) end
  return ready
end

ns:On("PLAYER_LEVEL_UP", function(level)
  level = ns.API.clean(level)
  -- Required levels are checked against UnitLevel, which may lag the event.
  if C_Timer then C_Timer.After(1, function() Notices.WishlistLevelUp(level) end) end
end)

-- Crafting ---------------------------------------------------------------------
-- /gearwright craft: crafted upgrades from every profession, with whether you
-- can make it yourself, need to learn the recipe, or should have it crafted.

local CRAFT_REASONS = {
  ["no-craft-data"] = "no recipes known yet; open a profession window with the probe or Gearwright loaded",
}
local CRAFT_SHOWN = 8

function Notices.Craft(retried)
  local rows, mine, pending = ns.Advisor.CraftReport()
  if not rows then
    ns.util.print("craft: %s", CRAFT_REASONS[mine] or tostring(mine))
    return
  end
  if pending > 0 and not retried and C_Timer then
    ns.util.print("reading %d crafted items...", pending)
    C_Timer.After(2, function() Notices.Craft(true) end)
    return
  end
  if #rows == 0 then
    ns.util.print("no crafted upgrades for you up to level %d",
      (ns.API.clean(UnitLevel("player")) or 0) + ns.Advisor.Lookahead())
  else
    ns.util.print("crafted upgrades:")
    for i = 1, math.min(#rows, CRAFT_SHOWN) do
      local r = rows[i]
      local s = describe({ link = r.link or r.name or ("item " .. r.itemID), delta = r.delta, slot = r.slot, reqLevel = r.reqLevel })
      print("  " .. s .. " |cff999999- " .. ns.Advisor.CraftStatusText(r) .. "|r")
    end
    if #rows > CRAFT_SHOWN then print(("  ...and %d more (see /gearwright -> Crafting)"):format(#rows - CRAFT_SHOWN)) end
  end
  if #mine == 0 then
    ns.util.print("open your professions once so Gearwright knows which recipes you have")
  end
  if pending > 0 then ns.util.print("%d items still not cached; run it again in a moment", pending) end
  return rows
end
