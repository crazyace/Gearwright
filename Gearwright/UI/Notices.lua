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
  local train = row.train or (row.link and ns.Advisor.TrainingNeeded(row.link))
  if train then s = s .. (" |cffff9900(train %s first)|r"):format(train) end
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

-- Weapon skills -------------------------------------------------------------------
-- /gearwright train: the weapon skills your class can use but you haven't
-- trained, who teaches them, and pins on the map.
function Notices.Train()
  local ctx, reason = ns.Advisor.Context()
  if not ctx then return ns.util.print("train: %s", tostring(reason)) end
  if not ctx.weaponSkills then
    return ns.util.print("train: this client doesn't say which weapon skills you know")
  end
  local missing = {}
  local prof = ctx.proficiency or ctx.class.proficiency
  for sub, skill in pairs(ctx.class.weaponSkills or {}) do
    if not ctx.weaponSkills[sub] and prof[2] and prof[2][sub] then missing[#missing + 1] = skill.name end
  end
  table.sort(missing)
  if #missing == 0 then return ns.util.print("you know every weapon skill your class can use") end
  local plan, unknown = ns.Trainers.Plan(missing)
  local WHERE = { [0] = " |cff40ff40(here)|r", [1] = "", [2] = " |cff999999(other continent)|r" }
  ns.util.print("weapon skills you can still train, nearest trainer first:")
  for _, g in ipairs(plan) do
    local t = g.trainer
    print(("  %s%s%s%s: %s"):format(t.name, t.city and (", " .. t.city) or "",
      t.detail and (" (" .. t.detail .. ")") or "", WHERE[g.distance] or "",
      table.concat(g.skills, ", ")))
  end
  if #unknown > 0 then print("  no trainer known: " .. table.concat(unknown, ", ")) end
  ns.Trainers.ShowPlan(plan)
  return missing
end

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
      (ns.API.clean(UnitLevel("player")) or 0) + ns.Advisor.CRAFT_LOOKAHEAD)
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
