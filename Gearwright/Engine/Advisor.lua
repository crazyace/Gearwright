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
    proficiency = Advisor.Proficiency(classData),
    dualWield = Advisor.CanDualWield(classData),
    weaponSkills = Advisor.KnownWeaponSkills(classData),
    weights = ns.Weights.Build(classData, spec, ns.API.CharacterSnapshot()),
  }
end

-- Gear ------------------------------------------------------------------------

-- Weapon subclasses whose skill you've trained: { [subclass] = true }, or nil
-- when the client doesn't answer (no skill known at all), so nothing is flagged.
function Advisor.KnownWeaponSkills(classData)
  if not classData.weaponSkills then return nil end
  local known, any = {}, false
  for sub, skill in pairs(classData.weaponSkills) do
    if ns.API.KnowsSpell(skill.spell) then known[sub] = true; any = true end
  end
  if not any then return nil end
  ns.WeaponSkills.Update(known) -- notices a skill that was just trained
  return known
end

-- "One-Handed Swords 1/95" when `link` is a weapon you've trained but whose
-- skill is still too low to fight well with (Engine/WeaponSkills.lua), else nil.
function Advisor.SkillTooLow(link, ctx)
  if not ctx then ctx = Advisor.Context() end
  if not (ctx and ctx.class.weaponSkills) then return nil end
  local _, _, classID, subclassID = ns.API.GetItemBasics(link)
  local skill = classID == 2 and ctx.class.weaponSkills[subclassID]
  if not skill or (ctx.weaponSkills and not ctx.weaponSkills[subclassID]) then return nil end
  return ns.WeaponSkills.Warning(subclassID, skill.name)
end

-- The weapon skill you'd have to train to use `link` ("One-Handed Swords"),
-- or nil when it's trained, not a weapon, or not known.
function Advisor.TrainingNeeded(link, ctx)
  if not ctx then ctx = Advisor.Context() end
  if not (ctx and ctx.weaponSkills and ctx.class.weaponSkills) then return nil end
  local _, _, classID, subclassID = ns.API.GetItemBasics(link)
  local skill = classID == 2 and ctx.class.weaponSkills[subclassID]
  if skill and not ctx.weaponSkills[subclassID] then return skill.name end
end

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

  local out = {}
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
    local item = "item:" .. r.itemID
    local reqLevel = ns.API.GetItemDetails(item)
    if not reqLevel then
      -- Not cached yet, or not an item we can read; equippability works uncached.
      if ns.API.GetItemBasics(item) and Advisor.CandidateSlots(item, ctx) then
        pending = pending + 1
        ns.API.RequestItem(r.itemID)
      end
    elseif reqLevel <= level + Advisor.CRAFT_LOOKAHEAD then
      local delta, slot = Advisor.CompareToEquipped(item, ctx)
      if delta == nil and (slot == "stats-unreadable" or slot == "equipped-unreadable") then
        pending = pending + 1
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
          profession = r.prof, status = status, alt = alt, train = Advisor.TrainingNeeded(item, ctx),
          lowSkill = Advisor.SkillTooLow(item, ctx),
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
                train = Advisor.TrainingNeeded(item, ctx), lowSkill = Advisor.SkillTooLow(item, ctx),
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
