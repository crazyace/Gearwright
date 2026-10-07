-- Gearwright: the advisors (gear, enchants, consumables, crafting).
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
  INVTYPE_THROWN = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_HOLDABLE = { 17 },
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
    proficiency = Advisor.Proficiency(classData),
    dualWield = Advisor.CanDualWield(classData),
    weights = ns.Weights.Build(classData, spec, ns.API.CharacterSnapshot(), ns.Spec.Talents()),
  }
end

-- Scores are worked out in attack power (melee) or points of spell power
-- (casters). Melee scores are shown as damage per second, the unit of the
-- game's own "+1.8 damage per second" comparison: 1 DPS = 14 attack power.
Advisor.AP_PER_DPS = 14

function Advisor.ScoreUnit()
  local classData = ns.Spec.ClassData()
  if classData and classData.weights.model ~= "caster" then return Advisor.AP_PER_DPS, "DPS" end
  return 1, nil
end

-- A score as shown: signed, one decimal (two under 1 DPS so small upgrades
-- don't read as +0.0).
function Advisor.FormatScore(v, signed)
  local per, unit = Advisor.ScoreUnit()
  v = v / per
  local s = ((unit and math.abs(v) < 1 and v ~= 0) and "%.2f" or "%.1f"):format(v)
  if signed and v >= 0 then s = "+" .. s end
  return s
end

-- Gear ------------------------------------------------------------------------

-- Whether a weapon can go in the off hand yet: the class's Dual Wield level
-- reached, or the spell known. Classes without a dualWield entry never can.
function Advisor.CanDualWield(classData)
  local dw = classData.dualWield
  if not dw then return false end
  local level = ns.API.clean(UnitLevel("player"))
  return (level and level >= dw.level) or (dw.spell and ns.API.KnowsSpell(dw.spell)) or false
end

-- The class's proficiency table plus any weapon types unlocked by a talent with
-- points in it or a known weapon skill spell.
function Advisor.Proficiency(classData)
  local base = classData.proficiency
  if not base or not classData.unlocks then return base end
  local talents = ns.API.ReadTalents(classData.traitTabGroups)
  local ranks = {}
  for _, tab in ipairs(talents and talents.tabs or {}) do
    for _, t in ipairs(tab.talents or {}) do
      if t.name then ranks[t.name] = math.max(ranks[t.name] or 0, t.rank or 0) end
    end
  end
  local out = {}
  for classID, subs in pairs(base) do
    out[classID] = {}
    for sub, ok in pairs(subs) do out[classID][sub] = ok end
  end
  for _, u in ipairs(classData.unlocks) do
    if (u.talent and (ranks[u.talent] or 0) > 0) or (u.spell and ns.API.KnowsSpell(u.spell)) then
      out[u.class] = out[u.class] or {}
      out[u.class][u.subclass] = true
    end
  end
  return out
end

local DAGGER = 15

-- Slots `link` could go in for this class and spec, or nil + reason:
--   "not-equippable", "not-usable" (armor/weapon type), "no-dual-wield" (off-hand
--   weapon before Dual Wield), "wrong-weapon-type" (spec rule).
function Advisor.CandidateSlots(link, ctx)
  local _, equipLoc, classID, subclassID = ns.API.GetItemBasics(link)
  local slots = equipLoc and EQUIP_LOC_TO_SLOTS[equipLoc]
  if not slots then return nil, "not-equippable" end
  -- Orbs and tomes: only for classes that list them (Specs.lua: holdables).
  if equipLoc == "INVTYPE_HOLDABLE" and not ctx.class.holdables then return nil, "not-usable" end

  local prof = ctx.proficiency or ctx.class.proficiency
  if prof and classID and prof[classID] and not prof[classID][subclassID] then
    return nil, "not-usable"
  end

  if classID == 2 and ctx.dualWield == false then
    local main = {}
    for _, slot in ipairs(slots) do
      if slot ~= 17 then main[#main + 1] = slot end
    end
    if #main == 0 then return nil, "no-dual-wield" end
    slots = main
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

-- `link` against what's equipped in every slot it could go in, best first:
--   { { slot, delta, newScore, oldScore, equipped }, ... }   or nil, reason
-- equipped is the link it would replace, nil for an empty slot.
function Advisor.CompareSlots(link, ctx)
  local reason
  if not ctx then ctx, reason = Advisor.Context() end
  if not ctx then return nil, reason end

  local slots, why = Advisor.CandidateSlots(link, ctx)
  if not slots then return nil, why end

  -- A two-hander replaces both hands, and anything in the off hand takes the
  -- place of an equipped two-hander, so those count as what you'd lose too.
  local _, equipLoc = ns.API.GetItemBasics(link)
  local mainHand = ns.API.GetEquippedLink(16)
  local mainIs2H = mainHand and select(2, ns.API.GetItemBasics(mainHand)) == "INVTYPE_2HWEAPON"

  local out = {}
  for _, slot in ipairs(slots) do
    local newScore = ns.Scoring.ScoreLink(link, ctx.weights, slot)
    if not newScore then return nil, "stats-unreadable" end
    local oldScore = 0 -- empty slot
    local equipped = ns.API.GetEquippedLink(slot)
    local lose = { { slot, equipped } } -- { slot, link } pairs
    if slot == 16 and equipLoc == "INVTYPE_2HWEAPON" then lose[2] = { 17, ns.API.GetEquippedLink(17) } end
    if slot == 17 and mainIs2H then
      equipped = mainHand
      lose = { { 16, mainHand } }
    end
    for _, l in ipairs(lose) do
      if l[2] then
        -- Unreadable (e.g. not cached yet) is not the same as empty: scoring it
        -- as 0 would make anything look like an upgrade.
        local score = ns.Scoring.ScoreLink(l[2], ctx.weights, l[1])
        if not score then return nil, "equipped-unreadable" end
        oldScore = oldScore + score
      end
    end
    out[#out + 1] = { slot = slot, delta = newScore - oldScore, newScore = newScore, oldScore = oldScore,
      equipped = equipped }
  end
  table.sort(out, function(a, b) return a.delta > b.delta end)
  return out
end

-- Score delta of `link` vs what it would replace, in the slot where it helps most.
-- Returns delta, slotID, newScore, oldScore, requiredLevel  (or nil, reason)
-- requiredLevel is set only when it's above your level.
function Advisor.CompareToEquipped(link, ctx)
  local list, why = Advisor.CompareSlots(link, ctx)
  if not list then return nil, why end
  local b = list[1]
  local best = { b.delta, b.slot, b.newScore, b.oldScore }

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

-- Consumables ---------------------------------------------------------------------
-- Weapon buffs, elixirs and potions (Data/Consumables.lua), scored by
-- Engine/Consumables.lua with the same weights as gear.

-- The report from Consumables.Report, plus for each weapon row `link` and
-- `active` (minutes left on the buff it has now, false for none, nil when the
-- client doesn't say).
function Advisor.ConsumableReport()
  local ctx, reason = Advisor.Context()
  if not ctx then return nil, reason end
  local data = ns.Data.CONSUMABLES
  if not data then return nil, "no-consumable-data" end

  local char = ns.API.CharacterSnapshot()
  local speeds = { [16] = ctx.weights.mainHandSpeed or char.mainHandSpeed, [17] = ctx.weights.offHandSpeed or char.offHandSpeed }
  local hands, links = {}, {}
  for _, slot in ipairs({ 16, 17 }) do
    local link = ns.API.GetEquippedLink(slot)
    local _, _, classID, subclassID = ns.API.GetItemBasics(link)
    if classID == 2 then
      hands[slot] = { kind = ns.Consumables.WeaponKind(subclassID), speed = speeds[slot] }
      links[slot] = link
    end
  end
  local _, classToken = ns.Spec.ClassData()
  local report = ns.Consumables.Report(data, {
    level = char.level or 1, lookahead = Advisor.Lookahead(), weights = ctx.weights,
    classToken = classToken, usesMana = ctx.class.weights.model == "caster", hands = hands,
  })
  local buffs = ns.API.GetWeaponBuffs()
  for _, row in ipairs(report.weapon) do
    row.link = links[row.slot]
    if buffs then row.active = buffs[row.slot] or false end
  end
  return report, ctx
end

-- Crafting ----------------------------------------------------------------------

Advisor.CRAFT_LOOKAHEAD = 5 -- default: also show items up to this many levels above you

-- How many levels ahead the Crafting list looks (settings).
function Advisor.Lookahead()
  local n = ns.db and tonumber(ns.db.lookahead)
  return n or Advisor.CRAFT_LOOKAHEAD
end
local CRAFT_UPGRADE = 0.5

-- Crafted upgrades from every profession, yours or not, best first. Recipes
-- come from Data/Crafted.lua (every profession the probe has scanned) and from
-- the profession windows you've opened (Engine/Professions.lua).
--   rows = { { recipeID, name, itemID, link, delta, slot, reqLevel, profession, status } }
--   status: "craft"  your profession, recipe learned
--           "alt"    one of your other characters knows the recipe (alt = their name)
--           "learn"  your profession, recipe not learned yet
--           "altlearn" an alt has the profession but not the recipe yet
--           "yours"  your profession, but its window hasn't been opened to check
--           "order"  nobody you have can make it: have someone craft it
-- Alts count when they're on your realm and faction (you can mail the item)
-- and the item doesn't bind on pickup.
-- Returns rows, mine (sorted names of your professions), pending
--   or nil, reason
function Advisor.CraftReport()
  local ctx, reason = Advisor.Context()
  if not ctx then return nil, reason end

  local known = ns.Professions.Known()          -- [prof] = { recipes } you've opened
  local alts = ns.Professions.Alts()
  local have = ns.API.PlayerProfessions()        -- [prof] = skill
  for name in pairs(known) do have[name] = have[name] or true end
  local mine = {}
  for name in pairs(have) do mine[#mine + 1] = name end
  table.sort(mine)

  -- One entry per (profession, item): your own scan wins, it knows "learned".
  local recipes, seen = {}, {}
  local function add(prof, r)
    local key = prof .. ":" .. tostring(r.itemID)
    if r.itemID and not seen[key] then
      seen[key] = true
      recipes[#recipes + 1] = { prof = prof, recipeID = r.recipeID, name = r.name, itemID = r.itemID, learned = r.learned }
    end
  end
  for prof, list in pairs(known) do
    for _, r in ipairs(list) do add(prof, r) end
  end
  for prof, items in pairs(ns.Professions.Catalog()) do
    for itemID, r in pairs(items) do add(prof, { recipeID = r.recipeID, itemID = itemID, name = r.name }) end
  end
  local data = ns.Data.CRAFTED
  for _, r in ipairs(data and data.recipes or {}) do
    add(data.professions[r[1]], { recipeID = r[2], itemID = r[3], name = r[4] })
  end
  if #recipes == 0 then return nil, "no-craft-data" end

  local level = ns.API.clean(UnitLevel("player")) or 1
  local rows, pending, best = {}, 0, {}
  for _, r in ipairs(recipes) do
    ns.util.Breathe() -- scoring every recipe is slow: let a background job pause here
    local item = "item:" .. r.itemID
    local reqLevel = ns.API.GetItemDetails(item)
    if not reqLevel then
      -- Not cached yet, or not an item we can read; equippability works uncached.
      if ns.API.GetItemBasics(item) and Advisor.CandidateSlots(item, ctx) and ns.API.RequestItem(r.itemID) then
        pending = pending + 1
      end
    elseif reqLevel <= level + Advisor.Lookahead() then
      local delta, slot = Advisor.CompareToEquipped(item, ctx)
      if delta == nil and slot == "stats-unreadable" then
        if ns.API.RequestItem(r.itemID) then pending = pending + 1 end
      elseif type(delta) == "number" and delta > CRAFT_UPGRADE then
        local status, alt = "order", nil
        if have[r.prof] then
          status = (r.learned == true and "craft") or (r.learned == false and "learn") or "yours"
        end
        if status ~= "craft" and ns.API.BindsOnPickup(item) ~= true then
          local who, rank = Advisor.AltFor(alts, r.prof, r.itemID)
          if who and Advisor.CRAFT_STATUS_ORDER[rank] < Advisor.CRAFT_STATUS_ORDER[status] then
            status, alt = rank, who
          end
        end
        local row = {
          recipeID = r.recipeID, name = r.name, itemID = r.itemID, link = ns.API.GetItemLink(item),
          delta = delta, slot = slot, reqLevel = reqLevel > level and reqLevel or nil,
          profession = r.prof, status = status, alt = alt,
        }
        -- An item several professions make: keep the one you can do most about.
        local prev = best[r.itemID]
        if not prev then
          best[r.itemID] = row
          rows[#rows + 1] = row
        elseif Advisor.CRAFT_STATUS_ORDER[status] < Advisor.CRAFT_STATUS_ORDER[prev.status] then
          for k, v in pairs(row) do prev[k] = v end
        end
      end
    end
  end
  table.sort(rows, function(x, y)
    if x.delta ~= y.delta then return x.delta > y.delta end
    return x.itemID < y.itemID
  end)
  return rows, mine, pending
end

Advisor.CRAFT_STATUS_ORDER = { craft = 1, alt = 2, learn = 3, altlearn = 4, yours = 5, order = 6 }

-- The alt best placed to make `itemID` with `prof`: one who knows the recipe
-- ("alt"), else one with the profession ("altlearn"). Returns name, status.
function Advisor.AltFor(alts, prof, itemID)
  local learner
  for _, a in ipairs(alts) do
    local recipes = a.professions[prof]
    if recipes then
      for _, r in ipairs(recipes) do
        if r.itemID == itemID then
          if r.learned then return a.name, "alt" end
          learner = learner or a.name
        end
      end
      learner = learner or a.name
    end
  end
  if learner then return learner, "altlearn" end
end

-- "you can craft this" / "learn it: Leatherworking" / "have it crafted: Blacksmithing"
function Advisor.CraftStatusText(row)
  local s = row.status
  if s == "craft" then return "you can craft it (" .. row.profession .. ")" end
  if s == "alt" then return row.alt .. " can craft it (" .. row.profession .. ")" end
  if s == "learn" then return "learn the recipe (" .. row.profession .. ")" end
  if s == "altlearn" then return row.alt .. " could learn it (" .. row.profession .. ")" end
  if s == "yours" then return row.profession .. ": open it to check the recipe" end
  return "have it crafted (" .. row.profession .. ")"
end

-- Gear overview ---------------------------------------------------------------
-- Every slot with what you wear and the best crafted upgrade Gearwright knows for it:
--   { { slot, name, link, score, best = { link, name, itemID, delta, reqLevel,
--       kind = "crafted", from = "you can craft it (Leatherworking)" } }, ... }, pending
function Advisor.GearOverview()
  local gear, reason = Advisor.GearReport()
  if not gear then return nil, reason end
  local best, pending = {}, 0
  local function offer(slot, cand)
    local b = slot and best[slot]
    if slot and (not b or cand.delta > b.delta or (cand.delta == b.delta and (cand.itemID or 0) < (b.itemID or 0))) then
      best[slot] = cand
    end
  end
  local crafted, _, p2 = Advisor.CraftReport()
  if type(p2) == "number" then pending = pending + p2 end
  for _, r in ipairs(type(crafted) == "table" and crafted or {}) do
    offer(r.slot, { link = r.link, name = r.name, itemID = r.itemID, delta = r.delta, reqLevel = r.reqLevel,
      kind = "crafted", from = Advisor.CraftStatusText(r) })
  end
  for _, g in ipairs(gear) do g.best = best[g.slot] end
  return gear, pending
end
