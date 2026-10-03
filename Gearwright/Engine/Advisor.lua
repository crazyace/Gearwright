-- Gearwright: the advisors (gear, talents, enchants, crafting).
-- Each returns plain tables; the UI decides how to show them.
local _, ns = ...

local Advisor = {}
ns.Advisor = Advisor

Advisor.SLOT_NAMES = {
  [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist",
  [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring 1",
  [12] = "Ring 2", [13] = "Trinket 1", [14] = "Trinket 2", [15] = "Back",
  [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged",
}
Advisor.SLOT_ORDER = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

local EQUIP_LOC_TO_SLOTS = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
  INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
  INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
  INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
  INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_WEAPONMAINHAND = { 16 },
  INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_RANGED = { 18 },
  INVTYPE_THROWN = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
}

-- Everything an advisor needs, or nil + reason.
function Advisor.Context()
  local classData = ns.Spec.ClassData()
  if not classData then return nil, "class-not-supported" end
  local spec, how = ns.Spec.Detect()
  if not spec then return nil, how end
  return {
    class = classData,
    spec = spec,
    specHow = how,
    weights = ns.Weights.Build(classData, spec, ns.API.CharacterSnapshot()),
  }
end

-- Gear ------------------------------------------------------------------------

local DAGGER = 15

-- Slots `link` could go in for this class and spec, or nil + reason:
--   "not-equippable", "not-usable" (armor/weapon type), "wrong-weapon-type" (spec rule).
function Advisor.CandidateSlots(link, ctx)
  local _, equipLoc, classID, subclassID = ns.API.GetItemBasics(link)
  local slots = equipLoc and EQUIP_LOC_TO_SLOTS[equipLoc]
  if not slots then return nil, "not-equippable" end

  local prof = ctx.class.proficiency
  if prof and classID and prof[classID] and not prof[classID][subclassID] then
    return nil, "not-usable"
  end

  local rules = ctx.class.specs[ctx.spec] and ctx.class.specs[ctx.spec].weapons
  if not rules or classID ~= 2 then return slots end
  local out = {}
  for _, slot in ipairs(slots) do
    local want = (slot == 16 and rules.mainHand) or (slot == 17 and rules.offHand) or "any"
    if want == "any" or (want == "dagger" and subclassID == DAGGER) then out[#out + 1] = slot end
  end
  if #out == 0 then return nil, "wrong-weapon-type" end
  return out
end

-- Score delta of `link` vs what it would replace, in the slot where it helps most.
-- Returns delta, slotID, newScore, oldScore, requiredLevel  (or nil, reason)
-- requiredLevel is set only when it's above your level.
function Advisor.CompareToEquipped(link, ctx)
  local reason
  if not ctx then ctx, reason = Advisor.Context() end
  if not ctx then return nil, reason end

  local slots, why = Advisor.CandidateSlots(link, ctx)
  if not slots then return nil, why end

  local best
  for _, slot in ipairs(slots) do
    local newScore = ns.Scoring.ScoreLink(link, ctx.weights, slot)
    if not newScore then return nil, "stats-unreadable" end
    local oldScore = 0 -- empty slot
    local equipped = ns.API.GetEquippedLink(slot)
    if equipped then
      -- Unreadable (e.g. not cached yet) is not the same as empty: scoring it
      -- as 0 would make anything look like an upgrade.
      oldScore = ns.Scoring.ScoreLink(equipped, ctx.weights, slot)
      if not oldScore then return nil, "equipped-unreadable" end
    end
    local delta = newScore - oldScore
    if not best or delta > best[1] then best = { delta, slot, newScore, oldScore } end
  end

  local reqLevel = ns.API.GetItemDetails(link)
  local level = ns.API.clean(UnitLevel("player"))
  if not (reqLevel and level and reqLevel > level) then reqLevel = nil end
  return best[1], best[2], best[3], best[4], reqLevel
end

function Advisor.GearReport()
  local ctx, reason = Advisor.Context()
  if not ctx then return nil, reason end
  local rows = {}
  for _, slot in ipairs(Advisor.SLOT_ORDER) do
    local link = ns.API.GetEquippedLink(slot)
    local score = link and ns.Scoring.ScoreLink(link, ctx.weights, slot)
    rows[#rows + 1] = { slot = slot, name = Advisor.SLOT_NAMES[slot], link = link, score = score }
  end
  return rows, ctx
end

-- Talents ---------------------------------------------------------------------

-- Rows where your rank differs from the recommended build.
function Advisor.TalentReport()
  local ctx, reason = Advisor.Context()
  if not ctx then return nil, reason end
  local build = ctx.class.builds and ctx.class.builds[ctx.spec]
  if not build or next(build.talents) == nil then return nil, "no-build-data" end

  local talents, why = ns.API.ReadTalents(ctx.class.traitTabGroups)
  if not talents then return nil, why end

  local have = {}
  for _, tab in ipairs(talents.tabs) do
    for _, t in ipairs(tab.talents) do have[t.name] = t.rank end
  end

  local rows = {}
  for name, want in pairs(build.talents) do
    local cur = have[name] or 0
    if cur ~= want then rows[#rows + 1] = { name = name, have = cur, want = want } end
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows, ctx
end

-- Enchants --------------------------------------------------------------------
-- Enchant effects come from Data/Enchants.lua (read from the beta's recipes);
-- each is scored with the same weights as gear.

local SLOT_ENCHANTS = {
  [2] = { "neck" }, [5] = { "chest" }, [8] = { "boots" }, [9] = { "bracer" },
  [10] = { "gloves" }, [15] = { "cloak" },
}
Advisor.ENCHANT_SLOTS = { 2, 15, 5, 9, 10, 8, 16, 17 }
local GOOD_ENOUGH = 0.5 -- attack-power equivalents

-- Enchant categories that fit the item in `slot`.
function Advisor.EnchantCategories(slot, link)
  if SLOT_ENCHANTS[slot] then return SLOT_ENCHANTS[slot] end
  if slot ~= 16 and slot ~= 17 then return {} end
  local _, equipLoc, classID = ns.API.GetItemBasics(link)
  if equipLoc == "INVTYPE_SHIELD" then return { "shield" } end
  if equipLoc == "INVTYPE_HOLDABLE" then return { "offhand" } end
  if classID ~= 2 then return {} end
  if equipLoc == "INVTYPE_2HWEAPON" then return { "weapon", "2h" } end
  return { "weapon" }
end

-- Best-scoring enchant for `slot`, or nil.
function Advisor.BestEnchant(slot, link, weights)
  local fits = {}
  for _, cat in ipairs(Advisor.EnchantCategories(slot, link)) do fits[cat] = true end
  local best
  for _, e in ipairs(ns.Data.ENCHANTS or {}) do
    if fits[e.cat] then
      local score = ns.Scoring.ScoreStats(e.stats, weights, slot)
      if score > 0 and (not best or score > best.score) then
        best = { name = e.name, id = e.id, score = score, stats = e.stats }
      end
    end
  end
  return best
end

-- One row per enchantable slot with an item in it:
--   { slot, name, link, best = {name, id, score}, current = "<tooltip text>" or nil,
--     currentScore (nil when the current enchant can't be scored), gain, ok }
function Advisor.EnchantReport()
  local ctx, reason = Advisor.Context()
  if not ctx then return nil, reason end
  if not ns.Data.ENCHANTS then return nil, "no-enchant-data" end

  local rows = {}
  for _, slot in ipairs(Advisor.ENCHANT_SLOTS) do
    local link = ns.API.GetEquippedLink(slot)
    local best = link and Advisor.BestEnchant(slot, link, ctx.weights)
    if best then
      local stats, text = ns.Stats.FromEnchantLine(ns.API.GetItemTooltipLines(link))
      local currentScore = 0
      if text then
        currentScore = next(stats) and ns.Scoring.ScoreStats(stats, ctx.weights, slot) or nil
      end
      local gain = currentScore and best.score - currentScore
      rows[#rows + 1] = {
        slot = slot, name = Advisor.SLOT_NAMES[slot], link = link, best = best,
        current = text, currentScore = currentScore, gain = gain,
        ok = (gain and gain < GOOD_ENOUGH) or false,
      }
    end
  end
  if #rows == 0 then return nil, "nothing-to-enchant" end
  return rows, ctx
end

-- Crafting ----------------------------------------------------------------------

Advisor.CRAFT_LOOKAHEAD = 5 -- also show items up to this many levels above you
local CRAFT_UPGRADE = 0.5

-- Upgrades among the recipes of the open profession window, best first:
--   rows = { { recipeID, name, learned, itemID, link, delta, slot, reqLevel } }
-- Returns rows, professionName, pending  (pending = items not cached yet)
--   or nil, reason
function Advisor.CraftReport()
  local ctx, reason = Advisor.Context()
  if not ctx then return nil, reason end
  local recipes, profession = ns.API.ReadRecipes()
  if not recipes then return nil, profession end

  local level = ns.API.clean(UnitLevel("player")) or 1
  local rows, pending = {}, 0
  for _, r in ipairs(recipes) do
    local item = r.itemID and ("item:" .. r.itemID)
    local reqLevel = item and ns.API.GetItemDetails(item)
    if item and not reqLevel then
      -- Not cached yet, or not an item we can read; equippability works uncached.
      if ns.API.GetItemBasics(item) and Advisor.CandidateSlots(item, ctx) then
        pending = pending + 1
        ns.API.RequestItem(r.itemID)
      end
    elseif item and reqLevel <= level + Advisor.CRAFT_LOOKAHEAD then
      local delta, slot = Advisor.CompareToEquipped(item, ctx)
      if delta == nil and (slot == "stats-unreadable" or slot == "equipped-unreadable") then
        pending = pending + 1
      elseif type(delta) == "number" and delta > CRAFT_UPGRADE then
        rows[#rows + 1] = {
          recipeID = r.recipeID, name = r.name, learned = r.learned, itemID = r.itemID,
          link = ns.API.GetItemLink(item), delta = delta, slot = slot,
          reqLevel = reqLevel > level and reqLevel or nil,
        }
      end
    end
  end
  table.sort(rows, function(a, b) return a.delta > b.delta end)
  return rows, profession, pending
end

-- Dungeons ---------------------------------------------------------------------
-- Upgrades among every dungeon boss drop, trash drop and dungeon quest reward
-- that a source addon knows about (Engine/Sources.lua), best first:
--   rows = { { itemID, name, link, delta, slot, reqLevel, sources = { ... } } }
-- Returns rows, ctx, pending  (pending = items not cached yet)   or nil, reason
function Advisor.DungeonReport()
  local ctx, reason = Advisor.Context()
  if not ctx then return nil, reason end
  local list = ns.Sources.All()
  if not list then return nil, "no-dungeon-data" end

  local level = ns.API.clean(UnitLevel("player")) or 1
  local faction = ns.API.PlayerFaction()
  local rows, byID, pending, checked = {}, {}, 0, {}
  for _, s in ipairs(list) do
    local otherFaction = s.faction and s.faction ~= "Both" and faction and s.faction ~= faction
    local item = "item:" .. s.itemID
    if not otherFaction and (byID[s.itemID] or not checked[s.itemID]) then
      if byID[s.itemID] then
        table.insert(byID[s.itemID].sources, s)
      else
        checked[s.itemID] = true
        if ns.API.GetItemBasics(item) and Advisor.CandidateSlots(item, ctx) then
          local reqLevel = ns.API.GetItemDetails(item)
          if not reqLevel then
            pending = pending + 1
            ns.API.RequestItem(s.itemID)
          elseif reqLevel <= level + Advisor.CRAFT_LOOKAHEAD then
            local delta, slot = Advisor.CompareToEquipped(item, ctx)
            if delta == nil and (slot == "stats-unreadable" or slot == "equipped-unreadable") then
              pending = pending + 1
            elseif type(delta) == "number" and delta > CRAFT_UPGRADE then
              local row = {
                itemID = s.itemID, name = s.name, link = ns.API.GetItemLink(item), delta = delta, slot = slot,
                reqLevel = reqLevel > level and reqLevel or nil, sources = { s },
              }
              byID[s.itemID] = row
              rows[#rows + 1] = row
            end
          end
        end
      end
    end
  end
  table.sort(rows, function(a, b) return a.delta > b.delta end)
  return rows, ctx, pending
end
