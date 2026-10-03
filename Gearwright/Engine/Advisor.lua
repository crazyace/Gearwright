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
    weights = classData.weights[spec],
  }
end

-- Gear ------------------------------------------------------------------------

-- Score delta of `link` vs the weakest equipped item it could replace.
-- Returns delta, slotID, newScore, oldScore  (or nil, reason)
function Advisor.CompareToEquipped(link)
  local ctx, reason = Advisor.Context()
  if not ctx then return nil, reason end

  local _, equipLoc = ns.API.GetItemBasics(link)
  local slots = equipLoc and EQUIP_LOC_TO_SLOTS[equipLoc]
  if not slots then return nil, "not-equippable" end

  local newScore = ns.Scoring.ScoreLink(link, ctx.weights)
  if not newScore then return nil, "stats-unreadable" end

  local worstSlot, worstScore
  for _, slot in ipairs(slots) do
    local equipped = ns.API.GetEquippedLink(slot)
    local score = equipped and ns.Scoring.ScoreLink(equipped, ctx.weights) or 0
    if not worstScore or score < worstScore then worstSlot, worstScore = slot, score end
  end
  return newScore - worstScore, worstSlot, newScore, worstScore
end

function Advisor.GearReport()
  local ctx, reason = Advisor.Context()
  if not ctx then return nil, reason end
  local rows = {}
  for _, slot in ipairs(Advisor.SLOT_ORDER) do
    local link = ns.API.GetEquippedLink(slot)
    local score = link and ns.Scoring.ScoreLink(link, ctx.weights)
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

  local talents, why = ns.API.ReadTalents()
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
