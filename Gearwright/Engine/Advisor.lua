-- Gearwright: the three advisors (gear, talents, enchants).
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
function Advisor.CompareToEquipped(link)
  local ctx, reason = Advisor.Context()
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

function Advisor.EnchantReport()
  local ctx, reason = Advisor.Context()
  if not ctx then return nil, reason end
  local recs = ctx.class.enchants and ctx.class.enchants[ctx.spec]
  if not recs or next(recs) == nil then return nil, "no-enchant-data" end

  local rows = {}
  for slot, rec in pairs(recs) do
    local link = ns.API.GetEquippedLink(slot)
    local current = link and ns.API.GetEnchantID(link) or 0
    rows[#rows + 1] = {
      slot = slot, name = Advisor.SLOT_NAMES[slot], current = current,
      want = rec.enchantID, wantName = rec.name, ok = current == rec.enchantID,
    }
  end
  table.sort(rows, function(a, b) return a.slot < b.slot end)
  return rows, ctx
end
